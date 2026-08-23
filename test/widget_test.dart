import 'package:flutter_test/flutter_test.dart';
import 'package:my_vault/main.dart';
import 'package:my_vault/state/vault_state.dart';
import 'package:my_vault/services/encryption_service.dart';
import 'package:my_vault/services/storage_service.dart';
import 'package:my_vault/services/biometric_service.dart';
import 'package:my_vault/services/supabase_service.dart';

void main() {
  testWidgets('MyVaultApp compiles and boots', (WidgetTester tester) async {
    // Initialize services
    final enc = EncryptionService();
    final stor = StorageService(enc);
    final bio = BiometricService();
    final sup = SupabaseService();
    final state = VaultState(stor, enc, bio, sup);

    // Boot App
    await tester.pumpWidget(MyVaultApp(vaultState: state));

    // Confirm MyVaultApp has booted successfully
    expect(find.byType(MyVaultApp), findsOneWidget);
  });
}
