// network_info_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkType {
  static const String wifi = 'wifi';
  static const String mobile = 'mobile';
  static const String none = 'none';
  static const String unknown = 'unknown';
}

class ConnectionQuality {
  static const String high = 'high';     // Fast WiFi or 5G
  static const String medium = 'medium';  // Good WiFi or 4G
  static const String low = 'low';       // Slow WiFi or 3G
  static const String poor = 'poor';     // Very slow or 2G
  static const String none = 'none';     // No connection
  static const String unknown = 'unknown'; // Connection quality not yet determined
}

class NetworkInfoService {
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();
  
  // Stream controller for network type changes
  final _networkTypeController = StreamController<String>.broadcast();
  Stream<String> get networkTypeStream => _networkTypeController.stream;
  
  // Current network state
  String _currentNetworkType = NetworkType.unknown;
  String _connectionQuality = ConnectionQuality.unknown;
  
  // Singleton pattern
  static final NetworkInfoService _instance = NetworkInfoService._internal();
  factory NetworkInfoService() => _instance;
  NetworkInfoService._internal() {
    _initNetworkMonitoring();
  }
  
  // Getters
  String get networkType => _currentNetworkType;
  String get connectionQuality => _connectionQuality;
  bool get isHighBandwidth => 
      _connectionQuality == ConnectionQuality.high || 
      _connectionQuality == ConnectionQuality.medium;
  bool get isLowBandwidth => 
      _connectionQuality == ConnectionQuality.low || 
      _connectionQuality == ConnectionQuality.poor;
  bool get hasConnection => _currentNetworkType != NetworkType.none;
  
  // Initialize network monitoring
  void _initNetworkMonitoring() {
    // Initial check
    _checkNetworkType();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      _checkNetworkType();
    });
  }
  
  // Check current network type and quality
  Future<void> _checkNetworkType() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      // Determine basic network type
      if (connectivityResult == ConnectivityResult.none) {
        _currentNetworkType = NetworkType.none;
        _connectionQuality = ConnectionQuality.none;
      } else if (connectivityResult == ConnectivityResult.wifi) {
        _currentNetworkType = NetworkType.wifi;
        await _estimateWifiQuality();
      } else if (connectivityResult == ConnectivityResult.mobile) {
        _currentNetworkType = NetworkType.mobile;
        await _estimateMobileQuality();
      } else {
        _currentNetworkType = NetworkType.unknown;
        _connectionQuality = ConnectionQuality.medium; // Default assumption
      }
      
      // Notify listeners
      _networkTypeController.add(_currentNetworkType);
      
      print('Network type: $_currentNetworkType, Quality: $_connectionQuality');
    } catch (e) {
      print('Error checking network type: $e');
      _currentNetworkType = NetworkType.unknown;
      _connectionQuality = ConnectionQuality.medium; // Default assumption
    }
  }
  
  // Estimate WiFi connection quality
  Future<void> _estimateWifiQuality() async {
    try {
      // Get WiFi details
      final wifiName = await _networkInfo.getWifiName();
      final wifiBSSID = await _networkInfo.getWifiBSSID();
      final wifiIP = await _networkInfo.getWifiIP();
      
      // For now, we'll use a simple heuristic based on WiFi name
      // In a real app, you might want to do speed tests or use historical data
      if (wifiName != null) {
        if (wifiName.toLowerCase().contains('5g') || 
            wifiName.toLowerCase().contains('5ghz')) {
          _connectionQuality = ConnectionQuality.high;
        } else {
          _connectionQuality = ConnectionQuality.medium;
        }
      } else {
        _connectionQuality = ConnectionQuality.medium; // Default for WiFi
      }
    } catch (e) {
      print('Error estimating WiFi quality: $e');
      _connectionQuality = ConnectionQuality.medium; // Default for WiFi
    }
  }
  
  // Estimate mobile connection quality
  Future<void> _estimateMobileQuality() async {
    try {
      // On Android, we could potentially use TelephonyManager to get network type
      // For now, we'll use a conservative estimate
      _connectionQuality = ConnectionQuality.low; // Default for mobile
    } catch (e) {
      print('Error estimating mobile quality: $e');
      _connectionQuality = ConnectionQuality.low; // Default for mobile
    }
  }
  
  // Force a refresh of network information
  Future<void> refreshNetworkInfo() async {
    await _checkNetworkType();
  }
  
  // Clean up resources
  void dispose() {
    _networkTypeController.close();
  }
}
