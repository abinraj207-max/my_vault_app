import 'dart:math';
import 'package:flutter/material.dart';
import '../models/role_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class RolesScreen extends StatefulWidget {
  final SupabaseService supabaseService;

  const RolesScreen({super.key, required this.supabaseService});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<Role> _roles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.supabaseService.fetchRoles();
      setState(() {
        _roles = data.map((e) => Role.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load roles: $e'), backgroundColor: Colors.redAccent),
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

  Future<void> _showRoleDialog({Role? existingRole}) async {
    final isEditing = existingRole != null;
    final nameController = TextEditingController(text: existingRole?.name ?? '');
    final descController = TextEditingController(text: existingRole?.description ?? '');

    bool canViewPasswords = existingRole?.canViewPasswords ?? false;
    bool canViewApiKeys = existingRole?.canViewApiKeys ?? false;
    bool canViewEmails = existingRole?.canViewEmails ?? false;
    bool canViewNotes = existingRole?.canViewNotes ?? false;
    bool canViewImages = existingRole?.canViewImages ?? false;
    bool canViewCards = existingRole?.canViewCards ?? false;
    bool canViewDocuments = existingRole?.canViewDocuments ?? false;
    bool canAddItems = existingRole?.canAddItems ?? false;
    bool canEditItems = existingRole?.canEditItems ?? false;
    bool canDeleteItems = existingRole?.canDeleteItems ?? false;
    bool canManageTeam = existingRole?.canManageTeam ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isEditing ? 'Edit Role' : 'Create Role',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Role Name
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Role Name',
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.highlight),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextField(
                        controller: descController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.description_outlined, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Category Permissions Header
                      const Text(
                        'Category Permissions',
                        style: TextStyle(color: AppColors.highlight, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),

                      _buildPermToggle('Passwords', Icons.lock_outline, canViewPasswords, (v) {
                        setDialogState(() => canViewPasswords = v);
                      }),
                      _buildPermToggle('API Keys', Icons.vpn_key_outlined, canViewApiKeys, (v) {
                        setDialogState(() => canViewApiKeys = v);
                      }),
                      _buildPermToggle('Emails', Icons.alternate_email, canViewEmails, (v) {
                        setDialogState(() => canViewEmails = v);
                      }),
                      _buildPermToggle('Secure Notes', Icons.note_outlined, canViewNotes, (v) {
                        setDialogState(() => canViewNotes = v);
                      }),
                      _buildPermToggle('Images', Icons.image_outlined, canViewImages, (v) {
                        setDialogState(() => canViewImages = v);
                      }),
                      _buildPermToggle('Cards', Icons.credit_card_outlined, canViewCards, (v) {
                        setDialogState(() => canViewCards = v);
                      }),
                      _buildPermToggle('Documents', Icons.description_outlined, canViewDocuments, (v) {
                        setDialogState(() => canViewDocuments = v);
                      }),

                      const SizedBox(height: 16),
                      const Text(
                        'Action Permissions',
                        style: TextStyle(color: AppColors.highlight, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),

                      _buildPermToggle('Can Add Items', Icons.add_circle_outline, canAddItems, (v) {
                        setDialogState(() => canAddItems = v);
                      }),
                      _buildPermToggle('Can Edit Items', Icons.edit_outlined, canEditItems, (v) {
                        setDialogState(() => canEditItems = v);
                      }),
                      _buildPermToggle('Can Delete Items', Icons.delete_outline, canDeleteItems, (v) {
                        setDialogState(() => canDeleteItems = v);
                      }),
                      const SizedBox(height: 16),
                      const Text(
                        'Team & Settings Permissions',
                        style: TextStyle(color: AppColors.highlight, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      _buildPermToggle('Manage Team & Roles', Icons.group_rounded, canManageTeam, (v) {
                        setDialogState(() => canManageTeam = v);
                      }),
                    ],
                  ),
                ),
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
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a role name')),
                      );
                      return;
                    }

                    final userId = widget.supabaseService.currentUser?.id;
                    if (userId == null) return;

                    final role = Role(
                      id: existingRole?.id ?? _generateUuidV4(),
                      ownerID: userId,
                      name: nameController.text.trim(),
                      description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                      canViewPasswords: canViewPasswords,
                      canViewApiKeys: canViewApiKeys,
                      canViewEmails: canViewEmails,
                      canViewNotes: canViewNotes,
                      canViewImages: canViewImages,
                      canViewCards: canViewCards,
                      canViewDocuments: canViewDocuments,
                      canAddItems: canAddItems,
                      canEditItems: canEditItems,
                      canDeleteItems: canDeleteItems,
                      canManageTeam: canManageTeam,
                    );

                    try {
                      await widget.supabaseService.upsertRole(role.toJson());
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save role: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  child: Text(isEditing ? 'Update' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _loadRoles();
    }
  }

  Widget _buildPermToggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: value ? AppColors.highlight : AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: value ? Colors.white : AppColors.textSecondary, fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.highlight,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRole(Role role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Role', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${role.name}"? Team members with this role will lose access.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.supabaseService.deleteRole(role.id);
        _loadRoles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete role: $e'), backgroundColor: Colors.redAccent),
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
        title: const Text('Manage Roles'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.highlight,
        foregroundColor: Colors.black,
        onPressed: () => _showRoleDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.highlight))
          : RefreshIndicator(
              onRefresh: _loadRoles,
              color: AppColors.highlight,
              child: _roles.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.admin_panel_settings_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                const Text('No roles yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                                const SizedBox(height: 8),
                                const Text('Tap + to create your first role', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: _roles.length,
                      itemBuilder: (context, index) {
                        final role = _roles[index];
                        return _buildRoleCard(role);
                      },
                    ),
            ),
    );
  }

  Widget _buildRoleCard(Role role) {
    // Collect enabled permissions
    final perms = <String>[];
    if (role.canViewPasswords) perms.add('Passwords');
    if (role.canViewApiKeys) perms.add('API Keys');
    if (role.canViewEmails) perms.add('Emails');
    if (role.canViewNotes) perms.add('Notes');
    if (role.canViewImages) perms.add('Images');
    if (role.canViewCards) perms.add('Cards');
    if (role.canViewDocuments) perms.add('Documents');

    final actions = <String>[];
    if (role.canAddItems) actions.add('Add');
    if (role.canEditItems) actions.add('Edit');
    if (role.canDeleteItems) actions.add('Delete');
    if (role.canManageTeam) actions.add('Manage Team');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRoleDialog(existingRole: role),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.highlight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: AppColors.highlight, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (role.description != null && role.description!.isNotEmpty)
                          Text(
                            role.description!,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _deleteRole(role),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Permissions chips
              if (perms.isNotEmpty) ...[
                const Text('View Access:', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: perms.map((p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.highlight.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.highlight.withOpacity(0.3)),
                    ),
                    child: Text(p, style: const TextStyle(color: AppColors.highlight, fontSize: 11, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
              ],
              if (perms.isEmpty)
                const Text('No view permissions', style: TextStyle(color: Colors.redAccent, fontSize: 12)),

              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Actions: ${actions.join(', ')}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
