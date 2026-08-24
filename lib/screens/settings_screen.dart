import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';
import 'cloud_sync_screen.dart';
import 'roles_screen.dart';
import 'team_members_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VaultState vaultState;

  const SettingsScreen({super.key, required this.vaultState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _storageStats = {
    'total': 0,
    'media': 0,
    'documents': 0,
    'database': 0,
  };
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStorageStats();
  }

  Future<void> _loadStorageStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await widget.vaultState.getStorageUsage();
      setState(() {
        _storageStats = stats;
        _isLoadingStats = false;
      });
    } catch (_) {
      setState(() => _isLoadingStats = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  void _changePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Master Password'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Master Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => obscureCurrent = !obscureCurrent,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value != widget.vaultState.masterPassword) {
                            return 'Incorrect current password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Master Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a new password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        await widget.vaultState.changeMasterPassword(
                          newPasswordController.text,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Master Password changed successfully!',
                              ),
                              backgroundColor: AppColors.surfaceVariant,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error changing password: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportBackup() async {
    try {
      final defaultName =
          'MyVault_Backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.vault';
      String? outputFile;

      final outputDirectory = await FilePicker.platform.getDirectoryPath();
      if (outputDirectory != null) {
        outputFile = '$outputDirectory/$defaultName';
      }

      if (outputFile != null) {
        await widget.vaultState.exportBackup(outputFile);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Backup exported to: ${outputFile!.split("/").last}',
              ),
              backgroundColor: AppColors.surfaceVariant,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup export failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import Backup?'),
          content: const Text(
            'Importing a backup will replace your current vault. Make sure you enter the correct master password of the backup files to unlock it afterward.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );

    if (proceed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (!path.endsWith('.vault')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid backup file. File must end with .vault'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        await widget.vaultState.importBackup(path);

        if (mounted) {
          // Lock the vault since we replaced index
          widget.vaultState.lockVault();
          Navigator.popUntil(
            context,
            (route) => route.isFirst,
          ); // Return to UnlockScreen

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Backup imported successfully! Enter master password to unlock.',
              ),
              backgroundColor: AppColors.surfaceVariant,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup import failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _wipeVaultDialog() {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmTextController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('WIPE ENTIRE VAULT?'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'WARNING: This operation will permanently delete your database, passwords, encrypted photos, and all other documents. '
                        'This action cannot be undone!',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Master Password',
                        ),
                        validator: (value) {
                          if (value != widget.vaultState.masterPassword) {
                            return 'Incorrect master password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmTextController,
                        decoration: const InputDecoration(
                          labelText: 'Type "DELETE" to confirm',
                          hintText: 'DELETE',
                        ),
                        validator: (value) {
                          if (value != 'DELETE') {
                            return 'Must type "DELETE" exactly';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context); // Close dialog

                      // Wipe the vault
                      await widget.vaultState.wipeVault();

                      if (context.mounted) {
                        Navigator.popUntil(
                          context,
                          (route) => route.isFirst,
                        ); // Pop to setup/unlock screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vault fully shredded and wiped from disk.',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: const Text('WIPE VAULT'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGroupCard(List<Widget> children) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // Security Settings
          _buildSectionHeader('Security'),
          _buildGroupCard([
            // ListTile(
            //   leading: const Icon(
            //     Icons.password_rounded,
            //     color: AppColors.highlight,
            //   ),
            //   title: const Text(
            //     'Change Master Password',
            //     style: TextStyle(
            //       color: Colors.white,
            //       fontWeight: FontWeight.w500,
            //     ),
            //   ),
            //   subtitle: const Text(
            //     'Update your decryption password',
            //     style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            //   ),
            //   trailing: const Icon(
            //     Icons.chevron_right_rounded,
            //     color: AppColors.highlight,
            //   ),
            //   onTap: _changePasswordDialog,
            // ),
            // const Divider(height: 1, indent: 56, color: AppColors.border),
            // SwitchListTile(
            //   secondary: const Icon(
            //     Icons.fingerprint_rounded,
            //     color: AppColors.highlight,
            //   ),
            //   title: const Text(
            //     'Biometric Unlock',
            //     style: TextStyle(
            //       color: Colors.white,
            //       fontWeight: FontWeight.w500,
            //     ),
            //   ),
            //   subtitle: const Text(
            //     'Unlock vault with fingerprint or Face ID',
            //     style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            //   ),
            //   value: widget.vaultState.biometricEnabled,
            //   onChanged: (val) async {
            //     if (val) {
            //       // Require password verification to enable
            //       final verifyController = TextEditingController();
            //       showDialog(
            //         context: context,
            //         builder: (context) {
            //           return AlertDialog(
            //             title: const Text('Enable Biometrics'),
            //             content: TextFormField(
            //               controller: verifyController,
            //               obscureText: true,
            //               decoration: const InputDecoration(
            //                 labelText: 'Enter Master Password',
            //               ),
            //             ),
            //             actions: [
            //               TextButton(
            //                 onPressed: () => Navigator.pop(context),
            //                 child: const Text('Cancel'),
            //               ),
            //               TextButton(
            //                 onPressed: () async {
            //                   final success = await widget.vaultState
            //                       .toggleBiometricUnlock(
            //                         true,
            //                         verifyController.text,
            //                       );
            //                   if (context.mounted) {
            //                     Navigator.pop(context);
            //                     if (success) {
            //                       ScaffoldMessenger.of(context).showSnackBar(
            //                         const SnackBar(
            //                           content: Text(
            //                             'Biometric unlock enabled.',
            //                           ),
            //                           backgroundColor: AppColors.surfaceVariant,
            //                         ),
            //                       );
            //                     } else {
            //                       ScaffoldMessenger.of(context).showSnackBar(
            //                         const SnackBar(
            //                           content: Text(
            //                             'Incorrect password. Biometrics not enabled.',
            //                           ),
            //                           backgroundColor: Colors.redAccent,
            //                         ),
            //                       );
            //                     }
            //                   }
            //                 },
            //                 child: const Text('Enable'),
            //               ),
            //             ],
            //           );
            //         },
            //       );
            //     } else {
            //       await widget.vaultState.toggleBiometricUnlock(false, '');
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(
            //           content: Text('Biometric unlock disabled.'),
            //           backgroundColor: AppColors.surfaceVariant,
            //         ),
            //       );
            //     }
            //   },
            // ),
            const Divider(height: 1, indent: 56, color: AppColors.border),
            ListTile(
              leading: const Icon(
                Icons.timer_outlined,
                color: AppColors.highlight,
              ),
              title: const Text(
                'Auto Lock Timer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                'Lock vault when app runs in background',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: widget.vaultState.autoLockTimeout,
                  dropdownColor: AppColors.surface,
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppColors.highlight,
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      widget.vaultState.updateAutoLockTimeout(val);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(
                        'Immediate',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 60,
                      child: Text(
                        '1 Minute',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 300,
                      child: Text(
                        '5 Minutes',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 600,
                      child: Text(
                        '10 Minutes',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: -1,
                      child: Text(
                        'Never',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, indent: 56, color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.lock_rounded, color: Colors.redAccent),
              title: const Text(
                'Lock Vault Now',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.redAccent,
              ),
              onTap: () {
                widget.vaultState.lockVault();
                Navigator.popUntil(context, (route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vault locked securely.'),
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                );
              },
            ),
          ]),

          // Cloud Settings
          _buildSectionHeader('Cloud Sync'),
          _buildGroupCard([
            ListTile(
              leading: const Icon(
                Icons.cloud_queue_rounded,
                color: AppColors.highlight,
              ),
              title: const Text(
                'Cloud Sync & Account',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                widget.vaultState.supabaseService.isLoggedIn
                    ? 'Connected: ${widget.vaultState.supabaseService.currentUser?.email}'
                    : 'Sync vault securely with Supabase',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.highlight,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CloudSyncScreen(vaultState: widget.vaultState),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
          ]),

          if (!widget.vaultState.isTeamMember ||
              (widget.vaultState.currentRole?.canManageTeam ?? false)) ...[
            // Team & Roles
            _buildSectionHeader('Team & Roles'),
            _buildGroupCard([
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.highlight,
                ),
                title: const Text(
                  'Manage Roles',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Create roles with custom permissions',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.highlight,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RolesScreen(
                        supabaseService: widget.vaultState.supabaseService,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 56, color: AppColors.border),
              ListTile(
                leading: const Icon(
                  Icons.group_rounded,
                  color: AppColors.highlight,
                ),
                title: const Text(
                  'Team Members',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Invite members & assign roles',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.highlight,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeamMembersScreen(
                        supabaseService: widget.vaultState.supabaseService,
                        vaultState: widget.vaultState,
                      ),
                    ),
                  );
                },
              ),
            ]),
          ],

          // Info / Privacy
          _buildSectionHeader('About & Privacy'),
          _buildGroupCard([
            ListTile(
              leading: const Icon(
                Icons.security_rounded,
                color: AppColors.highlight,
              ),
              title: const Text(
                'Privacy Commitment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'Your vault is secured client-side using zero-knowledge encryption and stored online in your Supabase backend. Encryption keys are derived locally from your Master Password, so your plaintext passwords are never transmitted or exposed to the server.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            // const Divider(height: 1, indent: 56, color: AppColors.border),
            // ListTile(
            //   leading: const Icon(
            //     Icons.delete_forever_rounded,
            //     color: Colors.redAccent,
            //   ),
            //   title: const Text(
            //     'Shred & Wipe Vault',
            //     style: TextStyle(
            //       color: Colors.redAccent,
            //       fontWeight: FontWeight.bold,
            //     ),
            //   ),
            //   subtitle: const Text(
            //     'Permanently delete the database and all files',
            //     style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            //   ),
            //   trailing: const Icon(
            //     Icons.chevron_right_rounded,
            //     color: Colors.redAccent,
            //   ),
            //   onTap: _wipeVaultDialog,
            // ),
          ]),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.highlight,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildStorageUsageSection() {
    final totalBytes = _storageStats['total'] as int? ?? 0;
    // Assume a visual cap of 50MB for visualization scale
    final double maxPercent = 50 * 1024 * 1024;
    final double percentVal = totalBytes / maxPercent;
    final displayPercent = (percentVal * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Storage Utilization',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AppColors.highlight,
                ),
                onPressed: _loadStorageStats,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingStats) ...[
            const Center(
              child: LinearProgressIndicator(
                color: AppColors.highlight,
                backgroundColor: AppColors.border,
              ),
            ),
          ] else ...[
            Row(
              children: [
                // Circular percentage chart
                Container(
                  height: 72,
                  width: 72,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 64,
                        width: 64,
                        child: CircularProgressIndicator(
                          value: percentVal > 0 ? percentVal : 0.01,
                          strokeWidth: 6,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.highlight,
                          ),
                        ),
                      ),
                      Text(
                        '$displayPercent%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _buildStatRow(
                        'Vault Size:',
                        _formatSize(_storageStats['total'] ?? 0),
                      ),
                      const SizedBox(height: 6),
                      _buildStatRow(
                        'Database Index:',
                        _formatSize(_storageStats['database'] ?? 0),
                      ),
                      const SizedBox(height: 6),
                      _buildStatRow(
                        'Images/Photos:',
                        _formatSize(_storageStats['media'] ?? 0),
                      ),
                      const SizedBox(height: 6),
                      _buildStatRow(
                        'Documents:',
                        _formatSize(_storageStats['documents'] ?? 0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
