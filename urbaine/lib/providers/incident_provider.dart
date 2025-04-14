// incident_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import 'auth_provider.dart';
import '../models/incident.dart';

class IncidentProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalDatabase _localDatabase = LocalDatabase();
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isOfflineMode = false;
  String _syncStatus = 'idle';
  List<Incident> _incidents = [];
  late AuthProvider _authProvider;
  
  IncidentProvider() {
    // Initialize with empty state
    _loadIncidents();
  }
  
  Future<void> _loadIncidents() async {
    try {
      final incidents = await _localDatabase.getIncidents();
      _incidents = incidents;
      notifyListeners();
    } catch (e) {
      print('Error loading incidents: $e');
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
  String? _error;
  bool _showOnlyOffline = false;

  // Set auth provider reference
  void setAuthProvider(AuthProvider provider) {
    _authProvider = provider;
    _isOfflineMode = provider.isOfflineMode;
    notifyListeners();
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

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  bool get showOnlyOffline => _showOnlyOffline;
  bool get isOfflineMode => _isOfflineMode;
  String get syncStatus => _syncStatus;

  set showOnlyOffline(bool value) {
    if (_showOnlyOffline != value) {
      _showOnlyOffline = value;
      notifyListeners();
    }
  }

  // Force complete loading if stuck
  void forceCompleteLoading() {
    if (_isLoading) {
      _isLoading = false;
      if (_incidents.isEmpty) {
        _localDatabase.getIncidents().then((localIncidents) {
          _incidents = localIncidents;
          _isOfflineMode = true;
          notifyListeners();
        });
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> loadIncidents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _isOfflineMode = _authProvider.isOfflineMode;

      if (!_isOfflineMode) {
        try {
          final apiIncidents = await _apiService.getIncidents();
          _incidents = apiIncidents;

          // Add unsynced local incidents
          final localIncidents = await _localDatabase.getUnsyncedIncidents();
          if (localIncidents.isNotEmpty) {
            _incidents.addAll(localIncidents);
          }

          _error = null;
        } catch (apiError) {
          // If the API fails, fallback to local
          _isOfflineMode = true;
          final localIncidents = await _localDatabase.getIncidents();
          _incidents = localIncidents;
        }
      } else {
        // If offline, load from local only
        final localIncidents = await _localDatabase.getIncidents();
        _incidents = localIncidents;
      }

      // Sort by creation date desc
      _incidents.sort((a, b) =>
          (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    } catch (e) {
      _error = 'Impossible de charger les incidents: $e';
      _incidents = [];
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
    final now = DateTime.now().toIso8601String();
    
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
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
      status: 'pending',
      isVoiceDescription: isVoiceDescription,
      isSynced: false,
    );

    String? permanentPhotoPath;
    try {
      if (photo != null) {
        // Copy photo to permanent storage
        final photosDirectory = await _photosDir;
        final fileName = path.basename(photo.path);
        final permanentFile = File('$photosDirectory/$fileName');
        await File(photo.path).copy(permanentFile.path);
        permanentPhotoPath = permanentFile.path;
      }

      var updatedIncident = incident.copyWith(
        photo: permanentPhotoPath
      );

      if (!_isOfflineMode) {
        try {
          // Try to create incident online
          final createdIncident = await _apiService.createIncident(
            updatedIncident,
            permanentPhotoPath != null ? XFile(permanentPhotoPath) : XFile(''),
          );
          _incidents.insert(0, createdIncident);
          notifyListeners();
          return createdIncident;
        } catch (e) {
          print('Error creating incident online: $e');
          // Fall back to offline storage
        }
      }

      // Store locally if offline or if online creation failed
      await _localDatabase.insertIncident(updatedIncident);
      _incidents.insert(0, updatedIncident);
      notifyListeners();
      return updatedIncident;
    } catch (e) {
      print('Error in createIncident: $e');
      rethrow;
    }


  }

  Future<void> syncIncidents() async {
    if (_isSyncing) return;
    if (_isOfflineMode) return;

    _isSyncing = true;
    _syncStatus = 'in_progress';
    _error = null; // Clear previous errors
    notifyListeners();

    try {
      final unsyncedList = await _localDatabase.getUnsyncedIncidents();
      if (unsyncedList.isEmpty) {
        _isSyncing = false;
        _syncStatus = 'idle';
        notifyListeners();
        return;
      }

      List<Incident> successfullySynced = [];

      // Process each incident individually for better error handling
      for (final incident in unsyncedList) {
        try {
          XFile? photoFile;
          if (incident.photo != null && incident.photo!.isNotEmpty) {
            final file = File(incident.photo!);
            if (await file.exists()) {
              photoFile = XFile(file.path);
            } else {
              print('Photo file not found: ${incident.photo}. Skipping incident.');
              continue;
            }
          }

          // Sync individual incident
          final syncedIncident = await _apiService.createIncident(incident, photoFile ?? XFile(''));
          successfullySynced.add(syncedIncident);

          // Update sync status immediately
          if (incident.localId != null) {
            await _localDatabase.updateIncidentSyncStatus(incident.localId!);
          }
        } catch (e) {
          print('Error syncing incident: $e');
          // Continue with next incident
        }
      }

      if (successfullySynced.isEmpty) {
        throw Exception('Failed to sync any incidents');
      }

      // Reload from server to refresh IDs & statuses
      await loadIncidents();

      _syncStatus = 'success';
    } catch (e) {
      _syncStatus = 'error';
      _error = 'Erreur lors de la synchronisation: $e';
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _startSyncTimer() {
    // Cancel existing
    _syncTimer?.cancel();
    // Attempt sync every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isSyncing && unsyncedIncidents.isNotEmpty && !_isOfflineMode) {
        await syncIncidents();
        // Don't cancel the timer even if all incidents are synced
        // This ensures we keep checking for connectivity changes
      }
    });
  }

  // E.g. let user manually trigger sync
  Future<void> manualSync() async {
    await syncIncidents();
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
        final localIncident = await _localDatabase.getIncidentByLocalId(incident.localId!);
        if (localIncident != null && localIncident.id != null) {
          await _localDatabase.deleteIncident(localIncident.id!);
        }
      } else if (incident.id != null) {
        // If we only have the server ID, try to delete by that
        await _localDatabase.deleteIncident(incident.id!);
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
