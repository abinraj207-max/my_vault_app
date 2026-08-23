import 'package:flutter/material.dart';
import 'services/encryption_service.dart';
import 'services/storage_service.dart';
import 'services/biometric_service.dart';
import 'services/supabase_service.dart';
import 'state/vault_state.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Fail silently to allow fallback to SharedPreferences configuration
  }

  // Instantiate services
  final encryptionService = EncryptionService();
  final storageService = StorageService(encryptionService);
  final biometricService = BiometricService();
  final supabaseService = SupabaseService();

  // Try to initialize Supabase connection with saved credentials
  await supabaseService.initialize();

  // Instantiate central state manager
  final vaultState = VaultState(
    storageService,
    encryptionService,
    biometricService,
    supabaseService,
  );

  runApp(MyVaultApp(vaultState: vaultState));
}

class MyVaultApp extends StatefulWidget {
  final VaultState vaultState;

  const MyVaultApp({super.key, required this.vaultState});

  @override
  State<MyVaultApp> createState() => _MyVaultAppState();
}

class _MyVaultAppState extends State<MyVaultApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register observer to listen to lifecycle states (for background auto-lock)
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Notify vault state about app lifecycle changes (auto-lock trigger)
    widget.vaultState.handleLifecycleStateChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vaultState,
      builder: (context, _) {
        return MaterialApp(
          title: 'MyVault',
          debugShowCheckedModeBanner: false,
          themeMode: widget.vaultState.themeMode,
          theme: AppTheme.themeData,
          darkTheme: AppTheme.themeData,
          home: _buildAppScreen(),
        );
      },
    );
  }

  Widget _buildAppScreen() {
    switch (widget.vaultState.status) {
      case VaultStatus.unlocked:
        return HomeScreen(vaultState: widget.vaultState);
      default:
        return AuthScreen(vaultState: widget.vaultState);
    }
  }
}
