import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/local_user_storage.dart';

/// Authentication status enum
enum AuthStatus {
  /// Initial state
  initial,
  
  /// Currently authenticating
  authenticating,
  
  /// Successfully authenticated
  authenticated,
  
  /// Authentication failed
  unauthenticated,
  
  /// In offline mode
  offlineMode,
  
  /// Error occurred during authentication
  error
}

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final LocalUserStorage _localUserStorage = LocalUserStorage();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  User? _user;
  bool _isAuthenticated = false;
  bool _isOfflineMode = false;
  bool _isBiometricEnabled = false;
  DateTime? _lastSuccessfulAuth;
  int _authFailureCount = 0;
  Timer? _authCheckTimer;
  AuthStatus _authStatus = AuthStatus.initial;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isOfflineMode => _isOfflineMode;
  bool get isBiometricEnabled => _isBiometricEnabled;
  AuthStatus get authStatus => _authStatus;
  bool get isInitializing => _authStatus == AuthStatus.initial;
  
  // Update offline mode status
  void updateOfflineStatus(bool isOnline) {
    if (isOnline && _isOfflineMode) {
      _isOfflineMode = false;
      notifyListeners();
      
      // Try to authenticate with backend when coming back online
      if (_isAuthenticated) {
        _tryOnlineAuthentication();
      }
    }
  }

  AuthProvider() {
    checkAuthStatus();
    _checkBiometricSupport();
    startAuthStateMonitor();
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
          // This ensures we can access the app offline
          _isAuthenticated = true;
          _isOfflineMode = true;
          print('Using locally stored user data for offline access');
          
          // Check if we can go online
          try {
            final isServerReachable = await _apiService.checkServerConnectivity()
                .timeout(const Duration(seconds: 3));
            if (isServerReachable) {
              // Now try to validate with backend if possible, but don't block access
              _tryOnlineAuthentication();
            } else {
              print('Server not reachable, staying in offline mode');
            }
          } catch (e) {
            print('Error checking server connectivity: $e');
          }
        } else {
          // No valid user in local storage despite isLocallyLoggedIn being true
          _isAuthenticated = false;
          _isOfflineMode = false;
          print('No valid user found in local storage');
        }
      } else {
        // No locally saved user, try online authentication
        try {
          // Check server connectivity first
          final isServerReachable = await _apiService.checkServerConnectivity()
              .timeout(const Duration(seconds: 3));
          
          if (!isServerReachable) {
            print('Server not reachable during initial auth check');
            _isAuthenticated = false;
            _isOfflineMode = true;
            
            // Check if we have cached user data for offline access
            final cachedUser = await _localUserStorage.getUser();
            if (cachedUser != null) {
              _user = cachedUser;
              _isAuthenticated = true;
              print('Using cached user data in offline mode');
            }
          } else {
            final token = await _apiService.getAccessToken();
            if (token != null) {
              try {
                _user = await _apiService.getCurrentUser()
                  .timeout(const Duration(seconds: 5), onTimeout: () {
                    throw Exception('API timeout');
                  });
                _isAuthenticated = true;
                _isOfflineMode = false;
                _lastSuccessfulAuth = DateTime.now();
                
                // Save for future offline use
                if (_user != null) {
                  await _localUserStorage.saveUser(_user!);
                  print('User data saved for offline access');
                }
              } catch (e) {
                print('Error getting current user: $e');
                // If we have a token but can't get user data, check if we have cached user data
                final cachedUser = await _localUserStorage.getUser();
                if (cachedUser != null) {
                  _user = cachedUser;
                  _isAuthenticated = true;
                  _isOfflineMode = true;
                  print('Using cached user data with existing token');
                } else {
                  _isAuthenticated = false;
                  _isOfflineMode = false;
                }
              }
            } else {
              _isAuthenticated = false;
              _isOfflineMode = false;
              print('No access token available');
            }
          }
        } catch (e) {
          print('Error checking auth status: $e');
          _isAuthenticated = false;
          
          // Check if we have cached user data for offline access
          final cachedUser = await _localUserStorage.getUser();
          if (cachedUser != null) {
            _user = cachedUser;
            _isAuthenticated = true;
            _isOfflineMode = true;
            print('Error during auth check, using cached user data');
          }
        }
      }
    } finally {
      _authStatus = AuthStatus.initial;
      notifyListeners();
    }
  }

  // Try to authenticate with the backend without blocking the UI
  Future<bool> _tryOnlineAuthentication() async {
    // First check if server is reachable
    try {
      print('Checking server connectivity before authentication...');
      final isServerReachable = await _apiService.checkServerConnectivity();
      if (!isServerReachable) {
        print('Server not reachable, switching to offline mode');
        _isOfflineMode = true;
        _authStatus = AuthStatus.offlineMode;
        notifyListeners();
        return false;
      }
      print('Server is reachable, proceeding with online authentication');
    } catch (e) {
      print('Error checking server connectivity: $e');
      _isOfflineMode = true;
      _authStatus = AuthStatus.offlineMode;
      notifyListeners();
      return false;
    }

    try {
      // Try to refresh the token
      await _apiService.refreshAccessToken();
      _lastSuccessfulAuth = DateTime.now();
      _authFailureCount = 0;
      _isOfflineMode = false;
      _authStatus = AuthStatus.authenticated;
      notifyListeners();
      print('Background authentication successful');
      return true;
    } catch (e) {
      _authFailureCount++;
      print('Background online authentication failed: $e');

      // If we've had too many failures, switch to offline mode
      if (_authFailureCount >= 3) {
        _isOfflineMode = true;
        _authStatus = AuthStatus.offlineMode;
        notifyListeners();
        print('Switched to offline mode after $_authFailureCount authentication failures');
      }
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      _authStatus = AuthStatus.authenticating;
      notifyListeners();
      print('Starting authentication process for user: $username');

      // Check if we can authenticate online
      final isServerReachable = await _apiService.checkServerConnectivity();
      
      if (isServerReachable) {
        try {
          final loginSuccess = await _apiService.login(username, password);
          if (loginSuccess) {
            // Login successful, now get the user data
            try {
              _user = await _apiService.getCurrentUser();
              if (_user != null) {
                // Save user data for offline use
                await _localUserStorage.saveUser(_user!);
                _isAuthenticated = true;
                _isOfflineMode = false;
                _authStatus = AuthStatus.authenticated;
                _lastSuccessfulAuth = DateTime.now();
                _authFailureCount = 0;
                notifyListeners();
                return true;
              } else {
                _authStatus = AuthStatus.error;
                notifyListeners();
                return false;
              }
            } catch (e) {
              _authFailureCount++;
              
              if (_authFailureCount >= 3) {
                if (await _canAuthenticateOffline(username, password)) {
                  _isOfflineMode = true;
                  _authStatus = AuthStatus.offlineMode;
                  notifyListeners();
                  return true;
                } else {
                  _authStatus = AuthStatus.error;
                  notifyListeners();
                  return false;
                }
              }
              
              _authStatus = AuthStatus.error;
              notifyListeners();
              return false;
            }
          } else {
            _authStatus = AuthStatus.unauthenticated;
            notifyListeners();
            return false;
          }
        } catch (e) {
          // If online auth fails, check if we have stored credentials for offline mode
          if (await _canAuthenticateOffline(username, password)) {
            _isOfflineMode = true;
            _authStatus = AuthStatus.offlineMode;
            _isAuthenticated = true;
            notifyListeners();
            return true;
          } else {
            _authStatus = AuthStatus.unauthenticated;
            notifyListeners();
            return false;
          }
        }
      } else {
        if (await _canAuthenticateOffline(username, password)) {
          _isOfflineMode = true;
          _authStatus = AuthStatus.offlineMode;
          _isAuthenticated = true;
          notifyListeners();
          return true;
        } else {
          _authStatus = AuthStatus.error;
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      _authStatus = AuthStatus.error;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricEnabled) {
      print('Biometric authentication not enabled');
      return false;
    }

    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Authentifiez-vous pour continuer',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (isAuthenticated) {
        // Get stored user data
        _user = await _localUserStorage.getUser();
        if (_user != null) {
          _isAuthenticated = true;
          _isOfflineMode = true; // Start in offline mode
          _authStatus = AuthStatus.authenticated;
          
          // Try to go online
          final isServerReachable = await _apiService.checkServerConnectivity();
          if (isServerReachable) {
            _isOfflineMode = false;
          } else {
            _authStatus = AuthStatus.offlineMode;
          }
          
          notifyListeners();
          return true;
        }
      }
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _authStatus = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      // Clear tokens
      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'refresh_token');
      
      // Clear user data
      _user = null;
      _isAuthenticated = false;
      _isOfflineMode = false;
      _authStatus = AuthStatus.unauthenticated;
      
      // Stop background auth check
      _authCheckTimer?.cancel();
      _authCheckTimer = null;
      
      notifyListeners();
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  Future<bool> checkAuthentication() async {
    try {
      print('Checking authentication status...');
      // Check if we have a stored token
      final token = await _secureStorage.read(key: 'auth_token');
      if (token == null) {
        print('No authentication token found');
        _authStatus = AuthStatus.unauthenticated;
        _isAuthenticated = false;
        notifyListeners();
        return false;
      }

      // Try to authenticate with the server
      final success = await _tryOnlineAuthentication();
      if (success) {
        print('Online authentication successful with stored token');
        _isAuthenticated = true;
        _authStatus = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }

      // If online authentication fails, check if we can use offline mode
      final userData = await _secureStorage.read(key: 'user_data');
      if (userData != null) {
        print('Using locally stored user data for offline access');
        _isAuthenticated = true;
        _isOfflineMode = true;
        _authStatus = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }

      print('Authentication failed: No valid credentials');
      _authStatus = AuthStatus.unauthenticated;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('Error checking authentication: $e');
      _authStatus = AuthStatus.error;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  // Start periodic background check for authentication status
  void startAuthStateMonitor() {
    _authCheckTimer?.cancel();
    
    // Check auth state every 5 minutes
    _authCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isAuthenticated && !_isOfflineMode) {
        // Check if we need to refresh based on last successful auth time
        final shouldRefresh = _lastSuccessfulAuth == null || 
            DateTime.now().difference(_lastSuccessfulAuth!).inHours >= 1;
            
        if (shouldRefresh) {
          print('Periodic auth check: Last successful auth was ${_lastSuccessfulAuth != null ? "${DateTime.now().difference(_lastSuccessfulAuth!).inMinutes} minutes ago" : "never"}');
          _tryOnlineAuthentication();
        }
      } else if (_isAuthenticated && _isOfflineMode) {
        // If we're offline but authenticated, check if we can go online
        print('Checking if we can go back online from offline mode');
        _apiService.checkServerConnectivity().then((isReachable) {
          if (isReachable) {
            print('Server is now reachable, attempting to go back online');
            _isOfflineMode = false;
            _tryOnlineAuthentication();
            notifyListeners();
          } else {
            print('Server still not reachable, staying in offline mode');
          }
        }).catchError((e) {
          print('Error checking server connectivity: $e');
          // Server still not reachable, stay offline
        });
      }
    });
  }
  
  @override
  void dispose() {
    _authCheckTimer?.cancel();
    super.dispose();
  }
  
  // Check if offline authentication is possible
  Future<bool> _canAuthenticateOffline(String username, String password) async {
    try {
      // Check if we have stored credentials
      final storedUser = await _localUserStorage.getUser();
      if (storedUser == null) {
        print('No stored user found for offline authentication');
        return false;
      }
      
      // Check if username matches
      if (storedUser.username != username) {
        print('Username mismatch for offline authentication');
        return false;
      }
      
      // In a real app, you would check the password hash here
      // For this demo, we'll just check if the username matches
      _user = storedUser;
      print('Offline authentication successful for user: ${storedUser.username}');
      return true;
    } catch (e) {
      print('Error during offline authentication: $e');
      return false;
    }
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
