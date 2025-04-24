// incident_provider.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import 'auth_provider.dart';
import '../models/incident.dart';
import 'connectivity_provider.dart';

class IncidentProvider with ChangeNotifier {
  static const int maxSyncRetries = 3; // Maximum number of sync retry attempts
  
  final ApiService _apiService = ApiService();
  final LocalDatabase _databaseHelper = LocalDatabase();
  Timer? _syncTimer;
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  String _syncErrorMessage = '';
  int _syncRetryCount = 0;
  DateTime? _lastSyncAttempt;
  bool _isOfflineMode = false;
  bool _showOnlyOffline = false;
  String? _error;
  List<Incident> _incidents = [];
  ConnectivityProvider? _connectivityProvider;

  IncidentProvider() {
    // Initialize with empty state
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    try {
      final incidents = await _databaseHelper.getIncidents();
      _incidents = incidents;
      _error = null; // Clear any previous errors
      notifyListeners();
    } catch (e) {
      print('Error loading incidents: $e');
      _error = 'Error loading incidents';
      notifyListeners();
    }
  }

  // Directory for storing photos permanently
  static Future<String> get _photosDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/incident_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir.path;
  }

  bool _isLoading = false;

  // Set auth provider reference
  void setAuthProvider(AuthProvider provider) {
    _isOfflineMode = provider.isOfflineMode;
    notifyListeners();
  }

  // Set connectivity provider reference
  void setConnectivityProvider(ConnectivityProvider provider) {
    _connectivityProvider = provider;

    // Listen to connectivity changes
    provider.connectivityStream.listen((isOnline) {
      print('Connectivity changed: isOnline = $isOnline');

      // Update offline mode status based on connectivity
      if (_isOfflineMode != !isOnline) {
        _isOfflineMode = !isOnline;
        print('Offline mode updated: $_isOfflineMode');
        notifyListeners();
      }

      // If we're back online and have unsynced incidents, try to sync them
      if (isOnline && unsyncedIncidents.isNotEmpty && !_isSyncing) {
        print('Network is available again with ${unsyncedIncidents.length} unsynced incidents');
        // Add a small delay to ensure connectivity is stable
        Future.delayed(const Duration(seconds: 2), () {
          if (_connectivityProvider?.isOnline == true) {
            print('Starting sync after connectivity restored');
            syncIncidents();
          }
        });
      }
    });

    // Initial status check
    _isOfflineMode = !provider.isOnline;
    print('Initial offline mode set to: $_isOfflineMode');
  }

  // Check if we can perform online operations using the connectivity provider
  bool _canPerformOnlineOperations() {
    final isOnline = _connectivityProvider?.isOnline ?? false;
    if (!isOnline) {
      print('Device is offline, cannot perform online operations');
      _syncStatus = 'offline';
      notifyListeners();
    }
    return isOnline;
  }

  List<Incident> get incidents {
    if (_showOnlyOffline) {
      return _incidents.where((incident) => !incident.isSynced).toList();
    }
    return _incidents;
  }

  List<Incident> get unsyncedIncidents =>
      _incidents.where((incident) => !incident.isSynced).toList();
  List<Incident> get syncedIncidents =>
      _incidents.where((incident) => incident.isSynced).toList();

  bool get isSyncing => _isSyncing;
  // Define a computed isLoading property that returns true if we're syncing
  bool get isLoading => _isSyncing;
  double get syncProgress => _syncProgress;
  String get syncStatus => _syncStatus;
  String get syncErrorMessage => _syncErrorMessage;
  String? get error => _error;
  int get syncRetryCount => _syncRetryCount;
  DateTime? get lastSyncAttempt => _lastSyncAttempt;
  bool get showOnlyOffline => _showOnlyOffline;
  bool get isOfflineMode => _isOfflineMode;

  set showOnlyOffline(bool value) {
    if (_showOnlyOffline != value) {
      _showOnlyOffline = value;
      notifyListeners();
    }
  }

  // Force complete loading if stuck
  void forceCompleteLoading() {
    if (_isLoading) {
      print('Force completing loading state');
      _isLoading = false;
      if (_incidents.isEmpty) {
        _databaseHelper.getIncidents().then((localIncidents) {
          _incidents = localIncidents;
          print('Loaded ${_incidents.length} incidents from local database');
          notifyListeners();
        }).catchError((e) {
          print('Error loading incidents from local database: $e');
        });
      }
      notifyListeners();
    }
  }

  Future<void> loadIncidents({bool forceRefresh = false}) async {
    // Don't reload if already loading, unless forced
    if (_isLoading && !forceRefresh) return;
    
    _isLoading = true;
    notifyListeners();
    
    print('Loading incidents (forceRefresh: $forceRefresh)');

    try {
      if (!_isOfflineMode) {
        // Try to load from API first
        try {
          final apiIncidents = await _apiService.getIncidents();
          if (apiIncidents.isNotEmpty) {
            _incidents = apiIncidents;
            // Save each incident to local database
            for (var incident in apiIncidents) {
              await _databaseHelper.insertIncident(incident);
            }
            print('Loaded ${apiIncidents.length} incidents from API');
          } else {
            // If API returns empty list, check if we have local incidents
            _incidents = await _databaseHelper.getIncidents();
            print('API returned no incidents, loaded ${_incidents.length} from local database');
          }
        } catch (e) {
          print('Error loading incidents from API: $e');
          _error = 'Failed to load incidents from server';
          // Fall back to local database
          _incidents = await _databaseHelper.getIncidents();
          print('Loaded ${_incidents.length} incidents from local database');
        }
      } else {
        // Load from local database only
        _incidents = await _databaseHelper.getIncidents();
        print('Offline mode: Loaded ${_incidents.length} incidents from local database');
      }

      // Sort by creation date desc
      _incidents.sort((a, b) =>
          (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    } catch (e) {
      print('Error loading incidents: $e');
      _error = 'Failed to load incidents';
    } finally {
      _isLoading = false;
      notifyListeners();

      // If we have unsynced data & we think we are online, start sync timer
      if (!_isOfflineMode && unsyncedIncidents.isNotEmpty) {
        _startSyncTimer();
      }
    }
  }

  Future<Incident> createIncident({
    required String incidentType,
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    String? address,
    XFile? photo,
    String? audioFile,
    bool isVoiceDescription = false,
  }) async {
    final localId = const Uuid().v4();
    final now = DateTime.now();

    // If there's a photo, copy it to permanent storage
    String? photoPath;
    if (photo != null) {
      try {
        final photosDirectory = await _photosDir;
        final fileName = '${localId}_${path.basename(photo.path)}';
        final permanentPath = path.join(photosDirectory, fileName);

        if (kIsWeb) {
          final bytes = await photo.readAsBytes();
          await File(permanentPath).writeAsBytes(bytes);
        } else {
          await File(photo.path).copy(permanentPath);
        }
        photoPath = permanentPath;
      } catch (e) {
        print('Error copying photo to permanent storage: $e');
        // Continue without the photo if there's an error
      }
    }

    // Create the incident object
    final incident = Incident(
      localId: localId,
      incidentType: incidentType,
      title: title,
      description: description,
      photo: photoPath,
      audioFile: audioFile,
      latitude: latitude,
      longitude: longitude,
      address: address,
      createdAt: now,
      updatedAt: now,
      status: 'pending',
      isVoiceDescription: isVoiceDescription,
      isSynced: false,
    );

    try {
      if (!_isOfflineMode) {
        try {
          // Try to create incident online
          final createdIncident = await _apiService.createIncident(
            incident,
            photoPath != null ? XFile(photoPath) : XFile(''),
          );
          
          // Save to local database and update in-memory list
          await _databaseHelper.insertIncident(createdIncident);
          _incidents.insert(0, createdIncident);
          notifyListeners();
          return createdIncident;
        } catch (e) {
          print('Error creating incident online: $e');
          // Fall back to offline storage
        }
      }

      // Store locally if offline or if online creation failed
      await _databaseHelper.insertIncident(incident);
      _incidents.insert(0, incident);
      notifyListeners();
      return incident;
    } catch (e) {
      print('Error creating incident: $e');
      _error = 'Failed to create incident';
      notifyListeners();
      return incident; // Return the incident even if there was an error, so we don't lose the data
    }
  }

  // Smart retry mechanism with exponential backoff
  void _scheduleAutoRetry() {
    _syncRetryCount++;
    final int delaySeconds = _syncRetryCount < 5
        ? (15 * _syncRetryCount) // 15s, 30s, 45s, 60s, 75s
        : 300; // 5 minutes max

    print('Scheduling auto-retry #$_syncRetryCount in $delaySeconds seconds');
    _syncStatus = 'retrying';
    notifyListeners();

    Future.delayed(Duration(seconds: delaySeconds), () {
      if (_incidents.any((incident) => !incident.isSynced)) {
        print('Auto-retrying sync #$_syncRetryCount after $delaySeconds seconds delay');
        syncIncidents();
      } else {
        print('No unsynced incidents found during retry check, cancelling retry');
        _syncRetryCount = 0;
        _syncStatus = 'success';
        notifyListeners();
      }
    });
  }

  Future<bool> syncIncidents() async {
    if (_isSyncing) {
      print('Sync already in progress, skipping');
      return false;
    }

    // Double-check connectivity before attempting to sync - use fast check to avoid UI delays
    final bool isServerReachable = await _apiService.fastConnectivityCheck();
    if (!isServerReachable) {
      print('Cannot sync incidents: server is unreachable');
      _syncStatus = 'offline';
      _syncErrorMessage = 'Pas de connectivité réseau. Veuillez réessayer plus tard.';
      notifyListeners();
      return false;
    }

    try {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncStatus = 'syncing';
      _lastSyncAttempt = DateTime.now();
      _syncErrorMessage = '';
      notifyListeners();
      print('Starting sync process at ${_lastSyncAttempt?.toIso8601String()}');

      // Get all unsynced incidents
      final unsyncedIncidents = _incidents.where((incident) => !incident.isSynced).toList();

      if (unsyncedIncidents.isEmpty) {
        print('No unsynced incidents to sync');
        _isSyncing = false;
        _syncProgress = 1.0;
        _syncStatus = 'success';
        _syncRetryCount = 0; // Reset retry count on success
        _syncErrorMessage = ''; // Clear any previous error message
        notifyListeners();
        return true;
      }

      print('Starting sync for ${unsyncedIncidents.length} incidents');

      int syncedCount = 0;
      List<String> failedIncidentIds = [];

      for (final incident in unsyncedIncidents) {
        try {
          // Update progress
          _syncProgress = syncedCount / unsyncedIncidents.length;
          notifyListeners();

          print('Syncing incident ${incident.id}');
          // Use the existing createIncident method instead of syncIncident
          XFile? photoFile;
          if (incident.photo != null && incident.photo!.isNotEmpty) {
            photoFile = XFile(incident.photo!);
          }
          // Try to use the fast connectivity check to catch network issues early
          final isConnected = await _apiService.fastConnectivityCheck();
          if (!isConnected) {
            throw Exception('Connection lost during sync operation');
          }
          
          final syncedIncident = await _apiService.createIncident(incident, photoFile ?? XFile(''));

          // Update the incident in the local list
          final index = _incidents.indexWhere((i) => i.id == incident.id);
          if (index != -1) {
            _incidents[index] = syncedIncident;
            if (incident.localId != null) {
              await _databaseHelper.updateIncidentSyncStatus(incident.localId!);
            }
            print('Incident ${incident.id ?? incident.localId} synced successfully');
          }

          syncedCount++;
        } catch (e) {
          print('Error syncing incident ${incident.id}: $e');
          failedIncidentIds.add((incident.id ?? incident.localId ?? 'unknown').toString());
          _syncErrorMessage = 'Erreur lors de la synchronisation: $e';
          // Continue with next incident
        }
      }

      // Update final progress
      _syncProgress = 1.0;

      if (failedIncidentIds.isEmpty) {
        _syncStatus = 'success';
        _syncRetryCount = 0; // Reset retry count on success
        _syncErrorMessage = ''; // Clear any error message on success
      } else {
        _syncStatus = 'partial';
        _syncErrorMessage = 'Certains incidents n\'ont pas pu être synchronisés. Réessai automatique en cours...';
        // Increment retry count if we had partial failures
        _syncRetryCount++;
        
        // Schedule a retry if appropriate
        if (_syncRetryCount <= maxSyncRetries) {
          _scheduleRetry();
        } else {
          _syncErrorMessage = 'La synchronisation a échoué après plusieurs tentatives. Veuillez vérifier votre connexion.';
          _syncRetryCount = 0; // Reset retry count after giving up
        }
      }

      notifyListeners();

      // Always reload incidents from server (if possible) after a sync attempt
      // This ensures we get any new incidents created on other devices
      try {
        if (_canPerformOnlineOperations()) {
          await loadIncidents(forceRefresh: true);
        }
      } catch (e) {
        print('Error reloading incidents after sync: $e');
      }
    } catch (e) {
      String errorMsg = e.toString();
      print('Sync error: $e');
      
      // Provide more user-friendly error messages
      if (errorMsg.contains('No network connectivity') || 
          errorMsg.contains('SocketException') || 
          errorMsg.contains('Connection lost')) {
        _syncErrorMessage = 'Pas de connexion réseau. Veuillez vérifier votre connexion Internet.';
      } else if (errorMsg.contains('token')) {
        _syncErrorMessage = 'Problème d\'authentification. Essayez de vous reconnecter.';
      } else {
        _syncErrorMessage = 'Erreur de synchronisation: ${errorMsg.length > 100 ? errorMsg.substring(0, 100) + '...' : errorMsg}';
      }
      
      _syncStatus = 'error';
      _isSyncing = false;
      
      // Schedule a retry for network errors
      if (errorMsg.contains('No network connectivity') || 
          errorMsg.contains('SocketException') || 
          errorMsg.contains('Connection lost')) {
        _syncRetryCount++;
        if (_syncRetryCount <= maxSyncRetries) {
          _scheduleRetry();
        }
      }
      
      notifyListeners();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();

      // Schedule auto-retry if there was an error
      if (_syncStatus == 'error' || _syncStatus == 'partial') {
        _scheduleAutoRetry();
      }
      
      return _syncStatus == 'success' || _syncStatus == 'partial';
    }
  }

  void _startSyncTimer() {
    // Cancel existing
    _syncTimer?.cancel();
    // Attempt sync every 2 minutes to reduce server load
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!_isSyncing && unsyncedIncidents.isNotEmpty) {
        print('Periodic sync check: ${unsyncedIncidents.length} incidents need syncing');

        // Only attempt sync if we're online
        if (_canPerformOnlineOperations()) {
          print('Attempting periodic sync');
          await syncIncidents();
        } else {
          print('Skipping periodic sync: device is offline');
        }
      } else if (unsyncedIncidents.isEmpty) {
        print('No unsynced incidents to sync');
      } else if (_isSyncing) {
        print('Sync already in progress');
      }
    });

    print('Sync timer started with interval: 2 minutes');
  }

  /// Try to reconnect and sync in the background when connectivity changes
  /// This is called when connectivity status changes to online
  void onConnectivityRestored() async {
    print('Connectivity restored, attempting background refresh...');
    try {
      final bool isConnected = await _apiService.fastConnectivityCheck();
      if (isConnected) {
        print('Background connectivity check successful, loading incidents');
        loadIncidents(forceRefresh: true);
        syncIncidents();
      } else {
        print('Background connectivity check failed, still offline');
      }
    } catch (e) {
      print('Error in background connectivity check: $e');
    }
  }
  
  /// Schedules a retry of the sync operation after a delay
  void _scheduleRetry() {
    // Exponential backoff for retries: 5s, 10s, 20s...
    final delaySeconds = 5 * (1 << (_syncRetryCount - 1));

    print('Scheduling auto-retry #$_syncRetryCount in $delaySeconds seconds');
    _syncStatus = 'retrying';
    notifyListeners();

    Future.delayed(Duration(seconds: delaySeconds), () {
      if (_incidents.any((incident) => !incident.isSynced)) {
        print('Auto-retrying sync #$_syncRetryCount after $delaySeconds seconds delay');
        syncIncidents();
      } else {
        print('No unsynced incidents found during retry check, cancelling retry');
        _syncRetryCount = 0;
        _syncStatus = 'success';
        notifyListeners();
      }
    });
  }

  // E.g. let user manually trigger sync
  Future<void> manualSync() async {
    // Reset sync status and retry count
    _syncStatus = '';
    _syncErrorMessage = '';
    _syncRetryCount = 0;
    notifyListeners();

    await syncIncidents();

    if (_syncStatus == 'error') {
      throw Exception(_syncErrorMessage.isNotEmpty ? _syncErrorMessage : 'Sync failed');
    }
  }

  // ... your deleteIncident etc. remain mostly the same ...
  // Just remove single-incident sync since we rely on the bulk approach now.

  Future<bool> deleteIncident(Incident incident) async {
    try {
      if (incident.id != null && !_isOfflineMode) {
        // TODO: Implémenter la suppression via API si nécessaire
        // For now, we'll just delete locally
      }
      
      if (incident.localId != null) {
        // Fix: Use localId for local database operations
        final localIncident = await _databaseHelper.getIncidentByLocalId(incident.localId!);
        if (localIncident != null && localIncident.id != null) {
          await _databaseHelper.deleteIncident(localIncident.id!);
        }
      } else if (incident.id != null) {
        // If we only have the server ID, try to delete by that
        await _databaseHelper.deleteIncident(incident.id!);
      }
      
      _incidents.removeWhere((i) => 
        (incident.id != null && i.id == incident.id) || 
        (incident.localId != null && i.localId == incident.localId)
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Impossible de supprimer l\'incident: $e';
      print('Delete incident error: $e');
      notifyListeners();
      return false;
    }
  }
}
