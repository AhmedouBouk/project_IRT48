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
import '../services/sync_queue_service.dart';
import '../services/network_info_service.dart';
import '../services/compression_service.dart';
import 'auth_provider.dart';
import '../models/incident.dart';
import 'connectivity_provider.dart';

class IncidentProvider with ChangeNotifier {
  static const int maxSyncRetries = 3; // Maximum number of sync retry attempts
  
  final ApiService _apiService = ApiService();
  final LocalDatabase _databaseHelper = LocalDatabase();
  final SyncQueueService _syncQueueService = SyncQueueService();
  final NetworkInfoService _networkInfo = NetworkInfoService();
  
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
  
  // Subscription to sync status updates
  StreamSubscription? _syncStatusSubscription;

  IncidentProvider() {
    // Initialize with empty state
    _initializeServices();
    _loadIncidents();
  }
  
  Future<void> _initializeServices() async {
    // Initialize the sync queue service
    await _syncQueueService.initialize();
    
    // Listen for sync status updates
    _syncStatusSubscription = _syncQueueService.syncStatusStream.listen((status) {
      _isSyncing = status['isSyncing'] ?? false;
      _syncStatus = status['syncStatus'] ?? '';
      _syncProgress = status['syncProgress'] ?? 0.0;
      notifyListeners();
    });
    
    // Restore sync status from persistent storage
    final syncStatus = await _apiService.getSyncStatus();
    _syncStatus = syncStatus['status'] ?? '';
    _syncErrorMessage = syncStatus['message'] ?? '';
    _syncProgress = syncStatus['progress'] ?? 0.0;
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

  Future<Incident?> createIncident({
    required String incidentType,
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    String? address,
    XFile? photo,
    String? audioFile,
    bool isVoiceDescription = false,
    int priority = 1, // Priority for sync queue
  }) async {
    final localId = const Uuid().v4();

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

    // Compress the photo if available and we're not on WiFi
    String? compressedPhotoPath = photoPath;
    if (photoPath != null && photoPath.isNotEmpty) {
      try {
        await _networkInfo.refreshNetworkInfo();
        if (_networkInfo.networkType != NetworkType.wifi) {
          // Use medium quality for storage to save space
          compressedPhotoPath = await CompressionService.compressImage(
            photoPath,
            quality: CompressionService.mediumQuality
          );
          print('Photo compressed for local storage: $compressedPhotoPath');
        }
      } catch (e) {
        print('Error compressing photo: $e');
        // Continue with original photo if compression fails
      }
    }
    
    // Save to local database
    final localIncident = Incident(
      localId: localId,
      incidentType: incidentType,
      title: title,
      description: description,
      photo: compressedPhotoPath,
      audioFile: audioFile,
      latitude: latitude,
      longitude: longitude,
      address: address,
      createdAt: DateTime.now(),
      isVoiceDescription: isVoiceDescription,
      userUsername: null, // Will be set by the server
      isSynced: false,
    );

    try {
      if (!_isOfflineMode) {
        try {
          // Try to create incident online
          final createdIncident = await _apiService.createIncident(
            localIncident,
            compressedPhotoPath != null ? XFile(compressedPhotoPath) : XFile(''),
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
      await _databaseHelper.insertIncident(localIncident);
      _incidents.insert(0, localIncident);
      notifyListeners();
      return localIncident;
    } catch (e) {
      print('Error creating incident: $e');
      _error = 'Failed to create incident';
      notifyListeners();
      return localIncident; // Return the incident even if there was an error, so we don't lose the data
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
      // Mark sync as started in the queue service
      await _syncQueueService.markSyncStarted();
      
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
        await _syncQueueService.markSyncCompleted(success: true);
        _isSyncing = false;
        _syncProgress = 1.0;
        _syncStatus = 'success';
        _syncRetryCount = 0; // Reset retry count on success
        _syncErrorMessage = ''; // Clear any previous error message
        notifyListeners();
        return true;
      }

      print('Starting sync for ${unsyncedIncidents.length} incidents');
      
      // Add all unsynced incidents to the sync queue
      for (final incident in unsyncedIncidents) {
        // Prioritize incidents with photos higher if on WiFi, lower if on mobile
        int priority = 1;
        if (incident.photo != null && incident.photo!.isNotEmpty) {
          priority = _networkInfo.networkType == NetworkType.wifi ? 2 : 0;
        }
        await _syncQueueService.addToQueue(incident, priority: priority);
      }

      // Get network info to determine optimal batch size and compression
      await _networkInfo.refreshNetworkInfo();
      final batchSize = _networkInfo.isLowBandwidth ? 3 : 5;
      print('Using batch size of $batchSize based on network conditions');

      // Process the queue in batches
      bool hasMoreItems = true;
      while (hasMoreItems && _isSyncing) {
        // Get the next batch of items to sync
        final batch = _syncQueueService.getNextBatch(batchSize: batchSize);
        if (batch.isEmpty) {
          hasMoreItems = false;
          continue;
        }
        
        print('Processing batch of ${batch.length} incidents');
        
        // Group by those with and without photos
        final List<Incident> batchIncidents = [];
        for (final queueItem in batch) {
          final incident = _incidents.firstWhere(
            (i) => i.localId == queueItem.localId || (i.id != null && i.id.toString() == queueItem.id),
            orElse: () => throw Exception('Incident not found in local list')
          );
          batchIncidents.add(incident);
        }
        
        // Sync the batch using the API service
        try {
          final syncedIncidents = await _apiService.syncIncidents(batchIncidents);
          
          // Update local database and memory for each synced incident
          for (final syncedIncident in syncedIncidents) {
            // Find the original incident
            final originalIncident = batchIncidents.firstWhere(
              (i) => (syncedIncident.localId != null && i.localId == syncedIncident.localId) ||
                    (i.id != null && syncedIncident.id != null && i.id == syncedIncident.id),
              orElse: () => throw Exception('Could not match synced incident to original')
            );
            
            // Update the incident in the local list
            final index = _incidents.indexWhere((i) => 
              (i.localId != null && i.localId == originalIncident.localId) ||
              (i.id != null && originalIncident.id != null && i.id == originalIncident.id)
            );
            
            if (index != -1) {
              _incidents[index] = syncedIncident;
              if (originalIncident.localId != null) {
                await _databaseHelper.updateIncidentSyncStatus(originalIncident.localId!);
              }
              
              // Mark as synced in the queue
              await _syncQueueService.markItemSynced(originalIncident.localId ?? '');
              
              print('Incident ${originalIncident.id ?? originalIncident.localId} synced successfully');
            }
          }
          
          // Check for any incidents that weren't synced
          for (final incident in batchIncidents) {
            final wasSynced = syncedIncidents.any((synced) => 
              (incident.localId != null && synced.localId == incident.localId) ||
              (incident.id != null && synced.id != null && synced.id == incident.id)
            );
            
            if (!wasSynced) {
              print('Incident ${incident.id ?? incident.localId} failed to sync');
              await _syncQueueService.markItemFailed(incident.localId ?? '');
            }
          }
        } catch (e) {
          print('Error syncing batch: $e');
          // Mark all items in the batch as failed
          for (final incident in batchIncidents) {
            await _syncQueueService.markItemFailed(incident.localId ?? '');
          }
        }
        
        // Update progress
        _syncProgress = _syncQueueService.syncProgress;
        notifyListeners();
      }

      // Check if there are any remaining items in the queue
      if (_syncQueueService.queueLength > 0) {
        _syncStatus = 'partial';
        _syncErrorMessage = 'Certains incidents n\'ont pas pu être synchronisés. Réessai automatique en cours...';
        _syncRetryCount++;
        
        // Schedule a retry if appropriate
        if (_syncRetryCount <= maxSyncRetries) {
          await _syncQueueService.markSyncCompleted(success: false);
          _scheduleRetry();
        } else {
          _syncErrorMessage = 'La synchronisation a échoué après plusieurs tentatives. Veuillez vérifier votre connexion.';
          _syncRetryCount = 0; // Reset retry count after giving up
          await _syncQueueService.markSyncCompleted(success: false);
        }
      } else {
        _syncStatus = 'success';
        _syncRetryCount = 0; // Reset retry count on success
        _syncErrorMessage = ''; // Clear any error message on success
        await _syncQueueService.markSyncCompleted(success: true);
      }

      notifyListeners();

      // Always reload incidents from server (if possible) after a sync attempt
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
      _syncProgress = 0.0;
      _isSyncing = false;
      await _syncQueueService.markSyncCompleted(success: false);
      notifyListeners();
      
      // If this was a retry and it failed, increment retry count
      if (_syncRetryCount > 0) {
        _syncRetryCount++;
        if (_syncRetryCount <= maxSyncRetries) {
          _scheduleRetry();
        } else {
          _syncRetryCount = 0; // Reset retry count after giving up
        }
      }
      
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    // This should never be reached due to the try/catch/finally structure
    return false;
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
