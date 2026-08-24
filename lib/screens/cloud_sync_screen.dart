import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';

class CloudSyncScreen extends StatefulWidget {
  final VaultState vaultState;

  const CloudSyncScreen({super.key, required this.vaultState});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  final _configFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmController = TextEditingController();

  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureSignupPassword = true;
  bool _obscureSignupConfirm = true;
  bool _obscureAnonKey = true;

  bool _isLoading = false;
  bool _isConfigured = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await widget.vaultState.supabaseService.getConfig();
    setState(() {
      _urlController.text = config['url'] ?? '';
      _anonKeyController.text = config['anonKey'] ?? '';
      _isConfigured = widget.vaultState.supabaseService.isInitialized;
    });
  }

  Future<void> _saveConfig() async {
    if (!_configFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await widget.vaultState.supabaseService.initialize(
        customUrl: _urlController.text.trim(),
        customAnonKey: _anonKeyController.text.trim(),
      );

      setState(() {
        _isConfigured = success;
        _isLoading = false;
        if (!success) {
          _errorMessage = 'Failed to initialize Supabase. Check URL and Anon Key.';
        }
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supabase connection configured successfully!'),
            backgroundColor: AppColors.surfaceVariant,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _disconnectConfig() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Supabase?'),
        content: const Text('This will clear the server URL and Anon Key, and sign you out. Your local offline vault will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    await widget.vaultState.supabaseService.clearConfig();
    setState(() {
      _urlController.clear();
      _anonKeyController.clear();
      _emailController.clear();
      _passwordController.clear();
      _isConfigured = false;
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase connection cleared.'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _signIn() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await widget.vaultState.supabaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      // Perform initial sync
      await widget.vaultState.syncWithCloud();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected and synced successfully!'), backgroundColor: AppColors.surfaceVariant),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign in failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _signUp() async {
    if (!_signupFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await widget.vaultState.supabaseService.signUp(
        _signupEmailController.text.trim(),
        _signupPasswordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registration Success'),
            content: const Text('Account registered! Please check your email to confirm the signup registration (if email verification is enabled on your Supabase project) and then sign in.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _tabController.animateTo(0);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Registration failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await widget.vaultState.supabaseService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out of cloud sync.'), backgroundColor: AppColors.surfaceVariant),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _manualSync() async {
    try {
      await widget.vaultState.syncWithCloud();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault sync completed!'), backgroundColor: AppColors.surfaceVariant),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _formatSyncTime(String? isoString) {
    if (isoString == null) return 'Never';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return 'Never';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cloud Sync & Account'),
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: widget.vaultState,
        builder: (context, _) {
          final isLoggedIn = widget.vaultState.supabaseService.isLoggedIn;
          
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            children: [
              // Security Architecture Note
              _buildZeroKnowledgeBanner(),
              const SizedBox(height: 20),

              if (!_isConfigured) ...[
                _buildConfigCard(),
              ] else if (!isLoggedIn) ...[
                _buildConfigHeader(),
                const SizedBox(height: 16),
                _buildAuthTabs(),
              ] else ...[
                _buildSyncStatusCard(),
              ],

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildErrorCard(),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildZeroKnowledgeBanner() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_person_rounded, color: AppColors.highlight, size: 24),
                SizedBox(width: 10),
                Text(
                  'Zero-Knowledge Sync',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your passwords, notes, files, and secrets are encrypted locally on this device using AES-256-GCM. '
              'The derived key is created locally from your Master Password using Argon2id.\n\n'
              'Only encrypted ciphertexts are uploaded to Supabase. Supabase never receives, stores, or transmits your '
              'plaintext data or your Master Password. If someone breaches the database, they see only unreadable random characters.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded, color: AppColors.highlight, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perfect Cryptographic Privacy. Completely Zero-Knowledge.',
                      style: TextStyle(color: AppColors.highlight, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _configFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Configure Supabase Connection',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set up your Supabase project parameters to connect. Enter your project URL and Anon public key.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Supabase Project URL',
                  hintText: 'https://your-project.supabase.co',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter project URL';
                  if (!val.startsWith('https://')) return 'URL must start with https://';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _anonKeyController,
                obscureText: _obscureAnonKey,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Supabase Anon Public Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureAnonKey ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscureAnonKey = !_obscureAnonKey),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter Anon Key';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveConfig,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Save & Connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            const Icon(Icons.cloud_done_rounded, color: AppColors.highlight, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Supabase Configured', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    _urlController.text,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 20),
              tooltip: 'Clear Connection Settings',
              onPressed: _isLoading ? null : _disconnectConfig,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAuthTabs() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.highlight,
            labelColor: AppColors.highlight,
            unselectedLabelColor: AppColors.textSecondary,
            dividerColor: AppColors.border,
            tabs: const [
              Tab(text: 'Sign In'),
              Tab(text: 'Sign Up'),
            ],
          ),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSignInTab(),
                _buildSignUpTab(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSignInTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Account Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Enter your email address';
                if (!val.contains('@')) return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Account Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter your password';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Sign In & Sync'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _signupFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _signupEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Register Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Enter an email';
                if (!val.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupPasswordController,
              obscureText: _obscureSignupPassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password (min. 6 chars)',
                prefixIcon: const Icon(Icons.lock_open_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureSignupPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscureSignupPassword = !_obscureSignupPassword),
                ),
              ),
              validator: (val) {
                if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupConfirmController,
              obscureText: _obscureSignupConfirm,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureSignupConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscureSignupConfirm = !_obscureSignupConfirm),
                ),
              ),
              validator: (val) {
                if (val != _signupPasswordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Create Cloud Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    final email = widget.vaultState.supabaseService.currentUser?.email ?? 'Unknown User';
    final lastSyncStr = _formatSyncTime(widget.vaultState.lastSyncTime);
    final isSyncing = widget.vaultState.isSyncing;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: AppColors.highlight, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cloud Sync Enabled',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Last Synced:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text(lastSyncStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = MediaQuery.of(context).size.width >= 850;
                final signOutBtn = OutlinedButton.icon(
                  onPressed: _isLoading || isSyncing ? null : _signOut,
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                );

                final syncBtn = ElevatedButton.icon(
                  onPressed: _isLoading || isSyncing ? null : _manualSync,
                  icon: isSyncing
                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
                );

                if (isDesktop) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(width: 160, child: signOutBtn),
                      const SizedBox(width: 16),
                      SizedBox(width: 160, child: syncBtn),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: signOutBtn),
                      const SizedBox(width: 16),
                      Expanded(child: syncBtn),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading || isSyncing ? null : _disconnectConfig,
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Change Connection Settings', style: TextStyle(fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmController.dispose();
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }
}
