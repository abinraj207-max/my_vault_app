import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/role_model.dart';
import '../models/team_member_model.dart';
import '../services/encryption_service.dart';
import '../services/supabase_service.dart';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';

class TeamMembersScreen extends StatefulWidget {
  final SupabaseService supabaseService;
  final VaultState vaultState;

  const TeamMembersScreen({super.key, required this.supabaseService, required this.vaultState});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  List<TeamMember> _members = [];
  List<Role> _roles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final memberData = await widget.supabaseService.fetchTeamMembers();
      final roleData = await widget.supabaseService.fetchRoles();
      setState(() {
        _members = memberData.map((e) => TeamMember.fromJson(e)).toList();
        _roles = roleData.map((e) => Role.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Future<void> _showAddMemberDialog() async {
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create at least one role first.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isCreating = false;
    String? selectedRoleId = _roles.first.id;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Add Team Member',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Email input
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Member Email',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.highlight),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Password input
                    TextField(
                      controller: passwordController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Login Password',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.highlight),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setDialogState(() => obscurePassword = !obscurePassword);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRoleId,
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.highlight),
                          items: _roles.map((role) {
                            return DropdownMenuItem(
                              value: role.id,
                              child: Text(role.name, style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedRoleId = value);
                          },
                        ),
                      ),
                    ),

                    if (isCreating) ...[
                      const SizedBox(height: 16),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.highlight)),
                          SizedBox(width: 10),
                          Text('Creating account...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.highlight,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isCreating ? null : () async {
                    final email = emailController.text.trim();
                    final password = passwordController.text;

                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid email')),
                      );
                      return;
                    }
                    if (password.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password must be at least 6 characters')),
                      );
                      return;
                    }

                    final ownerId = widget.supabaseService.currentUser?.id;
                    if (ownerId == null || selectedRoleId == null) return;

                    setDialogState(() => isCreating = true);

                    try {
                      // 1. Suppress auth state changes to prevent vault re-lock
                      widget.vaultState.suppressAuthChanges = true;

                      // 2. Save the owner's current session
                      final ownerSession = widget.supabaseService.client.auth.currentSession;

                      // 3. Setup their vault metadata
                      final encService = EncryptionService();
                      final salt = encService.generateRandomSalt(16);
                      final secretKey = await encService.deriveKey(password, salt);
                      final verificationMap = await encService.encryptText('vault_verified', secretKey);
                      final verificationJson = jsonEncode(verificationMap);

                      // 4. Create the new member's Supabase auth account
                      final signUpResponse = await widget.supabaseService.client.auth.signUp(
                        email: email,
                        password: password,
                        data: {
                          'vault_salt': base64.encode(salt),
                          'vault_verification': verificationJson,
                        },
                      );
                      final newMemberId = signUpResponse.user?.id;

                      // 4. Restore the owner's session
                      if (ownerSession != null && ownerSession.refreshToken != null) {
                        await widget.supabaseService.client.auth.setSession(ownerSession.refreshToken!);
                      }

                      // 5. Re-enable auth state changes
                      widget.vaultState.suppressAuthChanges = false;

                      if (newMemberId == null) {
                        throw Exception('Failed to create member account. The email may already exist.');
                      }

                      // 4. Encrypt the owner's SecretKey for the team member
                      final ownerKeyBytes = await widget.vaultState.secretKey!.extractBytes();
                      final ownerKeyBase64 = base64.encode(ownerKeyBytes);
                      final encryptedOwnerKeyMap = await encService.encryptText(ownerKeyBase64, secretKey);
                      
                      // 5. Add team member record with the new member's ID
                      await widget.supabaseService.addTeamMember({
                        'id': _generateUuidV4(),
                        'owner_id': ownerId,
                        'member_id': newMemberId,
                        'member_email': email,
                        'role_id': selectedRoleId,
                        'status': 'active',
                        'encrypted_owner_key': jsonEncode(encryptedOwnerKeyMap),
                      });

                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      widget.vaultState.suppressAuthChanges = false;
                      setDialogState(() => isCreating = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  child: const Text('Create & Invite'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team member account created successfully!'),
            backgroundColor: AppColors.surfaceVariant,
          ),
        );
      }
    }
  }

  Future<void> _changeRole(TeamMember member) async {
    if (_roles.isEmpty) return;

    String? selectedRoleId = member.roleID;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Change Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select new role for ${member.memberEmail}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRoleId,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.highlight),
                        items: _roles.map((role) {
                          return DropdownMenuItem(
                            value: role.id,
                            child: Text(role.name, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedRoleId = value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.highlight,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    try {
                      await widget.supabaseService.updateTeamMember(
                        member.id,
                        {'role_id': selectedRoleId},
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update role: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _removeMember(TeamMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Member', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove ${member.memberEmail} from your team?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.supabaseService.removeTeamMember(member.id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove member: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Team Members'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.highlight,
        foregroundColor: Colors.black,
        onPressed: _showAddMemberDialog,
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.highlight))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.highlight,
              child: _members.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                const Text('No team members', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                                const SizedBox(height: 8),
                                const Text('Tap + to invite a member', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        return _buildMemberCard(_members[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildMemberCard(TeamMember member) {
    final isPending = member.status == 'pending';
    final statusColor = isPending ? Colors.orangeAccent : AppColors.highlight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isPending ? Icons.schedule : Icons.person,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.memberEmail,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.highlight.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          member.roleName ?? 'Unknown Role',
                          style: const TextStyle(color: AppColors.highlight, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isPending ? 'Pending' : 'Active',
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'change_role') {
                  _changeRole(member);
                } else if (value == 'remove') {
                  _removeMember(member);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'change_role',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, color: AppColors.highlight, size: 20),
                      SizedBox(width: 8),
                      Text('Change Role', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text('Remove', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
