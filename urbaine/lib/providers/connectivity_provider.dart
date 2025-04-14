import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'auth_provider.dart';
import 'incident_provider.dart';
import '../services/api_service.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final ApiService _apiService = ApiService();
  StreamSubscription? _connectivitySubscription;
  Timer? _debounceTimer;
  Timer? _serverCheckTimer;
  
  bool _isOnline = true;
  bool _manualOfflineMode = false;
  bool _hasServerConnection = true;
  AuthProvider? _authProvider;
  IncidentProvider? _incidentProvider;
  
  // Duration for debouncing connectivity changes
  static const debounceDuration = Duration(seconds: 2);
  // Duration for periodic server checks
  static const serverCheckInterval = Duration(seconds: 30);

  bool get isOnline => _isOnline && !_manualOfflineMode && _hasServerConnection;

  ConnectivityProvider() {
    _initConnectivity();
    
    // Ne spécifions pas le type pour permettre la flexibilité
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((dynamic result) {
      // Cancel any pending debounce timer
      _debounceTimer?.cancel();
      
      // Debounce connectivity changes
      _debounceTimer = Timer(debounceDuration, () async {
        bool wasOnline = isOnline;
        
        if (result is List) {
          final firstResult = result.isNotEmpty ? result.first : ConnectivityResult.none;
          _isOnline = firstResult != ConnectivityResult.none;
        } else {
          _isOnline = result != ConnectivityResult.none;
        }
        
        // Check server connectivity if device is online
        if (_isOnline) {
          _hasServerConnection = await _checkServerConnectivity();
        } else {
          _hasServerConnection = false;
        }
        
        // If we've gone from offline to online, update providers
        if (!wasOnline && isOnline) {
          await _handleConnectionRestored();
        }
        
        notifyListeners();
      });
    });
  }

  // Allow manually setting offline mode for testing
  void setManualOfflineMode(bool offline) {
    bool wasOnline = isOnline;
    _manualOfflineMode = offline;
    
    // If we've gone from offline to online, update auth provider and trigger sync
    if (!wasOnline && isOnline) {
      if (_authProvider != null) {
        _authProvider!.updateOfflineStatus(true);
      }
      
      // Trigger sync when we come back online
      if (_incidentProvider != null && !offline) {
        _incidentProvider!.manualSync();
      }
    }
    
    notifyListeners();
  }
  
  // Set auth provider reference
  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }
  
  // Set incident provider reference
  void setIncidentProvider(IncidentProvider incidentProvider) {
    _incidentProvider = incidentProvider;
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      
      if (result is List) {
        final firstResult = result.isNotEmpty ? result.first : ConnectivityResult.none;
        _isOnline = firstResult != ConnectivityResult.none;
      } else {
        _isOnline = result != ConnectivityResult.none;
      }
      
      // Initial server connectivity check
      if (_isOnline) {
        _hasServerConnection = await _checkServerConnectivity();
      }
      
      // Start periodic server checks
      _startPeriodicServerCheck();
      
      notifyListeners();
    } catch (e) {
      print('Connectivity check error: $e');
      _isOnline = false;
      _hasServerConnection = false;
      notifyListeners();
    }
  }

  Future<bool> _checkServerConnectivity() async {
    try {
      return await _apiService.checkServerConnectivity();
    } catch (e) {
      print('Server connectivity check error: $e');
      return false;
    }
  }

  void _startPeriodicServerCheck() {
    _serverCheckTimer?.cancel();
    _serverCheckTimer = Timer.periodic(serverCheckInterval, (timer) {
      _performServerCheck();
    });
  }

  Future<void> _performServerCheck() async {
    if (_isOnline && !_manualOfflineMode) {
      bool previousServerConnection = _hasServerConnection;
      _hasServerConnection = await _checkServerConnectivity();
      
      if (!previousServerConnection && _hasServerConnection) {
        await _handleConnectionRestored();
      }
      
      notifyListeners();
    }
  }

  Future<void> _handleConnectionRestored() async {
    try {
      if (_authProvider != null) {
        _authProvider!.updateOfflineStatus(true);
      }
      
      if (_incidentProvider != null) {
        await _incidentProvider!.manualSync();
      }
    } catch (e) {
      print('Error handling connection restored: $e');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _debounceTimer?.cancel();
    _serverCheckTimer?.cancel();
    super.dispose();
  }
}