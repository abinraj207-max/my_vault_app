import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static const String _urlKey = 'supabase_url';
  static const String _anonKey = 'supabase_anon_key';
  
  // Default fallback placeholders (for standard developer configuration)
  static const String defaultUrl = 'https://your-project.supabase.co';
  static const String defaultAnonKey = 'your-anon-key';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase is not initialized. Please configure connection details.');
    }
    return Supabase.instance.client;
  }

  /// Attempts to initialize Supabase using env variables, saved credentials, or defaults.
  Future<bool> initialize({String? customUrl, String? customAnonKey}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save new config if provided
    if (customUrl != null && customAnonKey != null) {
      await prefs.setString(_urlKey, customUrl);
      await prefs.setString(_anonKey, customAnonKey);
    }

    // 1. Try to read from flutter_dotenv
    String url = '';
    String key = '';
    
    try {
      url = dotenv.env['SUPABASE_URL'] ?? '';
      key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    } catch (_) {}

    // Check if the loaded env variables are valid and not the defaults
    if (url.isEmpty || key.isEmpty || url == defaultUrl || key == defaultAnonKey) {
      // 2. Fallback to SharedPreferences
      url = prefs.getString(_urlKey) ?? '';
      key = prefs.getString(_anonKey) ?? '';
    }

    if (url.isEmpty || key.isEmpty || url == defaultUrl || key == defaultAnonKey) {
      return false;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: key,
        authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
      );
      _initialized = true;
      return true;
    } catch (e) {
      // If already initialized
      if (e.toString().contains('already initialized') || e.toString().contains('hasInstance')) {
        _initialized = true;
        return true;
      }
      return false;
    }
  }

  /// Get the saved configuration.
  Future<Map<String, String>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString(_urlKey) ?? '',
      'anonKey': prefs.getString(_anonKey) ?? '',
    };
  }

  /// Clear the saved configuration and sign out.
  Future<void> clearConfig() async {
    if (_initialized) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_anonKey);
    _initialized = false;
  }

  // --- Auth Operations ---
  
  bool get isLoggedIn {
    if (!_initialized) return false;
    return client.auth.currentUser != null;
  }

  User? get currentUser {
    if (!_initialized) return null;
    return client.auth.currentUser;
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // --- DB Operations ---

  Future<List<Map<String, dynamic>>> fetchItems() async {
    final response = await client
        .from('vault_items')
        .select('id, encrypted_data, created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> upsertItem(String id, String encryptedData, String updatedAt) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('User is not logged in');

    await client.from('vault_items').upsert({
      'id': id,
      'user_id': userId,
      'encrypted_data': encryptedData,
    });
  }

  Future<void> deleteItem(String id) async {
    await client.from('vault_items').delete().eq('id', id);
  }

  // --- Storage Operations ---

  Future<void> uploadFile(String remotePath, List<int> bytes) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('User is not logged in');

    // Storage path: user_id/file_name
    final fullPath = '$userId/$remotePath';

    await client.storage.from('vault_files').uploadBinary(
      fullPath,
      Uint8List.fromList(bytes),
      fileOptions: const FileOptions(upsert: true),
    );
  }

  Future<Uint8List> downloadFile(String remotePath) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('User is not logged in');

    final fullPath = '$userId/$remotePath';
    return await client.storage.from('vault_files').download(fullPath);
  }

  Future<void> deleteFile(String remotePath) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final fullPath = '$userId/$remotePath';
    await client.storage.from('vault_files').remove([fullPath]);
  }

  // --- Roles Operations ---

  Future<List<Map<String, dynamic>>> fetchRoles() async {
    final response = await client
        .from('roles')
        .select()
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> upsertRole(Map<String, dynamic> roleData) async {
    await client.from('roles').upsert(roleData);
  }

  Future<void> deleteRole(String roleId) async {
    await client.from('roles').delete().eq('id', roleId);
  }

  // --- Team Members Operations ---

  Future<List<Map<String, dynamic>>> fetchTeamMembers() async {
    final response = await client
        .from('team_members')
        .select('*, roles(name)')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addTeamMember(Map<String, dynamic> memberData) async {
    await client.from('team_members').insert(memberData);
  }

  Future<void> updateTeamMember(String memberId, Map<String, dynamic> updates) async {
    await client.from('team_members').update(updates).eq('id', memberId);
  }

  Future<void> removeTeamMember(String memberId) async {
    await client.from('team_members').delete().eq('id', memberId);
  }

  /// Check if the current user is a team member of any vault owner.
  /// Returns the team_member row with joined role data, or null.
  Future<Map<String, dynamic>?> getMyTeamMembership() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await client
        .from('team_members')
        .select('*, roles(*)')
        .eq('member_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    return response;
  }

  /// Fetch vault items belonging to a specific owner (for team member access).
  Future<List<Map<String, dynamic>>> fetchOwnerItems(String ownerId) async {
    final response = await client
        .from('vault_items')
        .select('id, encrypted_data, created_at')
        .eq('user_id', ownerId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Look up a user ID by their email address from team_members table.
  /// Used to auto-link members when they sign up.
  Future<void> activateTeamMember(String memberEmail, String memberId) async {
    await client
        .from('team_members')
        .update({'member_id': memberId, 'status': 'active'})
        .eq('member_email', memberEmail)
        .eq('status', 'pending');
  }
}
