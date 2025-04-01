import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  User? _user;
  bool _isAuthenticated = false;
  bool _isInitializing = true;
  bool _isBiometricEnabled = false;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitializing => _isInitializing;
  bool get isBiometricEnabled => _isBiometricEnabled;

  AuthProvider() {
    checkAuthStatus();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      _isBiometricEnabled = canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      _isBiometricEnabled = false;
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      final token = await _apiService.getAccessToken();
      if (token != null) {
        _user = await _apiService.getCurrentUser();
        _isAuthenticated = true;
      }
    } catch (e) {
      _isAuthenticated = false;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      await _apiService.login(username, password);
      _user = await _apiService.getCurrentUser();
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricEnabled) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason:
            'Veuillez vous authentifier pour accéder à l\'application',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        // Si l'authentification biométrique réussit, nous vérifions si l'utilisateur a un token valide
        final token = await _apiService.getAccessToken();
        if (token != null) {
          _user = await _apiService.getCurrentUser();
          _isAuthenticated = true;
          notifyListeners();
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final success = await _apiService.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

      if (success) {
        return await login(username, password);
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
