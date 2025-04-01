import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  
  bool _isOnline = true;
  bool _manualOfflineMode = false;

  bool get isOnline => _isOnline && !_manualOfflineMode;

  ConnectivityProvider() {
    _initConnectivity();
    
    // Ne spécifions pas le type pour permettre la flexibilité
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((dynamic result) {
      if (result is List) {
        // Si c'est une liste, prenons le premier élément ou considérons comme déconnecté
        final firstResult = result.isNotEmpty ? result.first : ConnectivityResult.none;
        _isOnline = firstResult != ConnectivityResult.none;
      } else {
        // Si c'est un seul résultat
        _isOnline = result != ConnectivityResult.none;
      }
      notifyListeners();
    });
  }

  // Allow manually setting offline mode for testing
  void setManualOfflineMode(bool offline) {
    _manualOfflineMode = offline;
    notifyListeners();
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      // Traiter le résultat de manière générique
      if (result is List) {
        final firstResult = result.isNotEmpty ? result.first : ConnectivityResult.none;
        _isOnline = firstResult != ConnectivityResult.none;
      } else {
        _isOnline = result != ConnectivityResult.none;
      }
      notifyListeners();
    } catch (e) {
      print('Connectivity check error: $e');
      _isOnline = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}