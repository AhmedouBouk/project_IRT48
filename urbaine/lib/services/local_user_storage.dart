import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class LocalUserStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Save user data locally
  Future<void> saveUser(User user) async {
    await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));
    await _storage.write(key: 'last_login', value: DateTime.now().toIso8601String());
  }
  
  // Get locally saved user
  Future<User?> getUser() async {
    final userData = await _storage.read(key: 'user_data');
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }
  
  // Check if user is logged in locally
  Future<bool> isLoggedIn() async {
    // For offline mode, we only need user data to be present
    // Don't require token to be valid as it might be expired
    final userData = await _storage.read(key: 'user_data');
    return userData != null;
  }
  
  // Get last login time
  Future<DateTime?> getLastLogin() async {
    final lastLogin = await _storage.read(key: 'last_login');
    if (lastLogin != null) {
      return DateTime.parse(lastLogin);
    }
    return null;
  }
  
  // Clear user data
  Future<void> clearUser() async {
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'last_login');
  }
}
