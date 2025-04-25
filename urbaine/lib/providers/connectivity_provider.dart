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
  
  // Stream controller for exposing connectivity changes to other providers
  final StreamController<bool> _connectivityStreamController = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool _hasServerConnection = true;
  AuthProvider? _authProvider;
  IncidentProvider? _incidentProvider;

  // Duration for debouncing connectivity changes
  static const debounceDuration = Duration(seconds: 2);
  // Duration for periodic server checks
  static const serverCheckInterval = Duration(seconds: 30);

  bool get isOnline => _isOnline && _hasServerConnection;
  
  // Stream of connectivity changes that can be listened to by other providers
  Stream<bool> get connectivityStream => _connectivityStreamController.stream;

  ConnectivityProvider() {
    _initConnectivity();

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((dynamic result) {
      _debounceTimer?.cancel();

      _debounceTimer = Timer(debounceDuration, () async {
        bool wasOnline = isOnline;

        if (result is List) {
          final firstResult =
              result.isNotEmpty ? result.first : ConnectivityResult.none;
          _isOnline = firstResult != ConnectivityResult.none;
        } else {
          _isOnline = result != ConnectivityResult.none;
        }

        if (_isOnline) {
          _hasServerConnection = await _checkServerConnectivity();
        } else {
          _hasServerConnection = false;
        }

        if (!wasOnline && isOnline) {
          await _handleConnectionRestored();
        }
        
        // Emit the new connectivity state to the stream
        _connectivityStreamController.add(isOnline);
        notifyListeners();
      });
    });
  }

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  void setIncidentProvider(IncidentProvider incidentProvider) {
    _incidentProvider = incidentProvider;
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();

      if (result is List) {
        final firstResult =
            result.isNotEmpty ? result.first : ConnectivityResult.none;
        _isOnline = firstResult != ConnectivityResult.none;
      } else {
        _isOnline = result != ConnectivityResult.none;
      }

      if (_isOnline) {
        _hasServerConnection = await _checkServerConnectivity();
      }

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
    if (_isOnline) {
      bool previousServerConnection = _hasServerConnection;
      _hasServerConnection = await _checkServerConnectivity();

      if (!previousServerConnection && _hasServerConnection) {
        await _handleConnectionRestored();
        // Emit the connectivity change to the stream
        _connectivityStreamController.add(true);
      }

      notifyListeners();
    }
  }

  Future<void> _handleConnectionRestored() async {
    try {
      _authProvider?.updateOfflineStatus(true);
      await _incidentProvider?.manualSync();
    } catch (e) {
      print('Error handling connection restored: $e');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _debounceTimer?.cancel();
    _serverCheckTimer?.cancel();
    _connectivityStreamController.close();
    super.dispose();
  }
}
