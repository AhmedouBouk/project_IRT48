import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/local_user_storage.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final LocalUserStorage _localUserStorage = LocalUserStorage();
  User? _user;
  bool _isAuthenticated = false;
  bool _isInitializing = true;
  bool _isBiometricEnabled = false;
  bool _isOfflineMode = false;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitializing => _isInitializing;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isOfflineMode => _isOfflineMode;
  
  // Update offline mode status
  void updateOfflineStatus(bool isOnline) {
    if (isOnline && _isOfflineMode) {
      _isOfflineMode = false;
      notifyListeners();
    }
  }

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
      // First, check if we have a locally saved user regardless of token
      // This ensures we can work offline even if the token is expired
      final isLocallyLoggedIn = await _localUserStorage.isLoggedIn();
      
      if (isLocallyLoggedIn) {
        // We have a locally saved user, try to get it
        _user = await _localUserStorage.getUser();
        
        if (_user != null) {
          // We have a valid user from local storage
          // Now try to validate with backend if possible
          try {
            final token = await _apiService.getAccessToken();
            if (token != null) {
              // Try to get fresh user data from API with a short timeout
              _user = await _apiService.getCurrentUser()
                  .timeout(const Duration(seconds: 2), onTimeout: () {
                throw Exception('API timeout');
              });
              _isAuthenticated = true;
              _isOfflineMode = false;
              
              // Update local user data
              await _localUserStorage.saveUser(_user!);
            } else {
              // No token but we have local user - use offline mode
              _isAuthenticated = true;
              _isOfflineMode = true;
              print('No token, using offline user');
            }
          } catch (e) {
            // API error or timeout - use offline mode with local user
            _isAuthenticated = true;
            _isOfflineMode = true;
            print('API error, using offline user: $e');
          }
        } else {
          // No valid user in local storage despite isLocallyLoggedIn being true
          _isAuthenticated = false;
          _isOfflineMode = false;
        }
      } else {
        // No locally saved user, try online authentication
        try {
          final token = await _apiService.getAccessToken();
          if (token != null) {
            _user = await _apiService.getCurrentUser();
            _isAuthenticated = true;
            _isOfflineMode = false;
            
            // Save for future offline use
            if (_user != null) {
              await _localUserStorage.saveUser(_user!);
            }
          } else {
            _isAuthenticated = false;
            _isOfflineMode = false;
          }
        } catch (e) {
          print('Online auth error: $e');
          _isAuthenticated = false;
          _isOfflineMode = false;
        }
      }
    } catch (e) {
      print('Auth check error: $e');
      _isAuthenticated = false;
      _isOfflineMode = false;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      await _apiService.login(username, password);
      _user = await _apiService.getCurrentUser();
      
      // Save user data for offline use
      if (_user != null) {
        await _localUserStorage.saveUser(_user!);
      }
      
      _isAuthenticated = true;
      _isOfflineMode = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Login error: $e');
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
    await _localUserStorage.clearUser();
    _user = null;
    _isAuthenticated = false;
    _isOfflineMode = false;
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
