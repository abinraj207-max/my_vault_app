import 'package:flutter/material.dart';
import '../state/vault_state.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final VaultState vaultState;

  const AuthScreen({super.key, required this.vaultState});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  final _configFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmController = TextEditingController();
  final _unlockPasswordController = TextEditingController();

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
        // Trigger state refresh/auth changes subscribe
        widget.vaultState.checkVaultStatus();
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

  Future<void> _signIn() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final password = _passwordController.text;
      await widget.vaultState.supabaseService.signIn(
        _emailController.text.trim(),
        password,
      );
      
      // Immediately unlock the vault using the same password!
      await widget.vaultState.unlockVault(password);
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
      final password = _signupPasswordController.text;
      final response = await widget.vaultState.supabaseService.signUp(
        _signupEmailController.text.trim(),
        password,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (response.session != null) {
          // Auto-logged in! Instantly create the vault using the signup password
          setState(() => _isLoading = true);
          try {
            await widget.vaultState.createNewVault(password);
          } catch (e) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Vault creation failed: ${e.toString()}';
            });
          }
          return;
        }

        // Email confirmation is required
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo
                const Icon(
                  Icons.shield_outlined,
                  size: 80,
                  color: AppColors.highlight,
                ),
                const SizedBox(height: 12),
                const Text(
                  'MyVault',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Zero-Knowledge Online Password & Document Vault',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (!_isConfigured) ...[
                  _buildConfigForm(),
                ] else if (widget.vaultState.supabaseService.isLoggedIn) ...[
                  _buildUnlockForm(),
                ] else ...[
                  _buildAuthTabs(),
                ],

                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildErrorCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigForm() {
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
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your project URL and Anon public key to initialize.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 20),
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
            height: 370,
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
                  : const Text('Sign In to Vault'),
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

  Widget _buildUnlockForm() {
    final email = widget.vaultState.supabaseService.currentUser?.email ?? '';
    final formKey = GlobalKey<FormState>();
    
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
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Unlock your Vault',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Account: $email',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _unlockPasswordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Enter Account Password',
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
                onPressed: _isLoading ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  try {
                    await widget.vaultState.unlockVault(_unlockPasswordController.text);
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _errorMessage = 'Unlock failed: ${e.toString()}';
                      });
                    }
                  }
                },
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Unlock Vault'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  try {
                    await widget.vaultState.supabaseService.signOut();
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _errorMessage = 'Sign out failed: $e';
                      });
                    }
                  }
                },
                child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
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
    _unlockPasswordController.dispose();
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }
}
