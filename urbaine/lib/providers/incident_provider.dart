import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../models/incident.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import '../providers/auth_provider.dart';

class IncidentProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalDatabase _localDb = LocalDatabase();
  final Uuid _uuid = const Uuid();
  late AuthProvider _authProvider;
  
  List<Incident> _incidents = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  bool _showOnlyOffline = false;
  bool _isOfflineMode = false;
  Timer? _syncTimer;

  // Set auth provider reference
  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    _isOfflineMode = authProvider.isOfflineMode;
  }

  List<Incident> get incidents {
    if (_showOnlyOffline) {
      // Return only unsynchronized incidents
      return _incidents.where((incident) => !incident.isSynced).toList();
    }
    return _incidents;
  }

  // Getter for only unsynchronized incidents
  List<Incident> get unsyncedIncidents => 
      _incidents.where((incident) => !incident.isSynced).toList();
  
  // Getter for only synchronized incidents
  List<Incident> get syncedIncidents => 
      _incidents.where((incident) => incident.isSynced).toList();
  
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  bool get showOnlyOffline => _showOnlyOffline;
  bool get isOfflineMode => _isOfflineMode;
  
  // Force complete loading in case of timeout
  void forceCompleteLoading() {
    if (_isLoading) {
      _isLoading = false;
      // If we have no incidents, try to load from local database as a fallback
      if (_incidents.isEmpty) {
        _localDb.getIncidents().then((localIncidents) {
          _incidents = localIncidents;
          _isOfflineMode = true;
          notifyListeners();
        });
      } else {
        notifyListeners();
      }
    }
  }

  // Toggle showing only offline incidents
  void toggleOfflineFilter() {
    _showOnlyOffline = !_showOnlyOffline;
    notifyListeners();
  }

  // Setter for showing only offline incidents
  set showOnlyOffline(bool value) {
    if (_showOnlyOffline != value) {
      _showOnlyOffline = value;
      notifyListeners();
    }
  }

  // Charger les incidents depuis l'API ou localement
  Future<void> loadIncidents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Vérifier si nous sommes en mode hors ligne
      _isOfflineMode = _authProvider.isOfflineMode;
      
      if (!_isOfflineMode) {
        // Mode en ligne: essayer de charger depuis l'API d'abord
        try {
          final apiIncidents = await _apiService.getIncidents()
              .timeout(const Duration(seconds: 5), onTimeout: () {
            throw TimeoutException('API request timed out');
          });
          _incidents = apiIncidents;
          
          // Ensuite, ajouter les incidents stockés localement qui ne sont pas encore synchronisés
          final localIncidents = await _localDb.getUnsyncedIncidents();
          if (localIncidents.isNotEmpty) {
            _incidents.addAll(localIncidents);
          }
          
          _error = null;
        } catch (apiError) {
          print('API Error: $apiError');
          _isOfflineMode = true;
          // Charger depuis la base de données locale
          final localIncidents = await _localDb.getIncidents();
          _incidents = localIncidents;
        }
      } else {
        // Mode hors ligne: charger directement depuis la base de données locale
        final localIncidents = await _localDb.getIncidents();
        _incidents = localIncidents;
      }
      
      // Trier par date de création
      _incidents.sort((a, b) => 
        (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now())
      );
      
    } catch (e) {
      print('Error loading incidents: $e');
      _error = 'Impossible de charger les incidents.';
      _incidents = [];
    } finally {
      _isLoading = false;
      notifyListeners();
      
      // Si nous avons des incidents non synchronisés et que nous sommes en ligne,
      // démarrer un timer pour essayer de les synchroniser périodiquement
      if (!_isOfflineMode && unsyncedIncidents.isNotEmpty) {
        _startSyncTimer();
      }
    }
  }

  // Créer un nouvel incident et envoyer à l'API
  Future<bool> createIncident({
    required String incidentType,
    required String title,
    required String description,
    required XFile photoFile,
    required double latitude,
    required double longitude,
    String? address,
    bool isVoiceDescription = false,
    String? audioPath,
  }) async {
    try {
      // Générer un ID local pour le suivi
      final localId = _uuid.v4();
      
      final incident = Incident(
        localId: localId,
        incidentType: incidentType,
        title: title,
        description: description,
        latitude: latitude,
        longitude: longitude,
        address: address,
        isVoiceDescription: isVoiceDescription,
        createdAt: DateTime.now(),
        isSynced: false,
      );

      // Si nous sommes en ligne, essayer d'envoyer à l'API d'abord
      if (_isConnected()) {
        try {
          // Ajouter un timeout pour éviter que l'app ne se bloque indéfiniment
          final createdIncident = await _apiService.createIncident(
            incident, 
            photoFile
          ).timeout(const Duration(seconds: 10), onTimeout: () {
            // En cas de timeout, on considère qu'on est hors ligne
            throw Exception('Connection timeout');
          });
          
          _incidents.insert(0, createdIncident);
          notifyListeners();
          return true;
        } catch (e) {
          print('API Error: $e');
          // Si l'API échoue, enregistrer localement
        }
      }
      
      // Si nous ne sommes pas en ligne ou si l'API a échoué
      // Sur le web, nous ne pouvons pas stocker le chemin du fichier
      String? photoPath;
      if (!kIsWeb) {
        photoPath = photoFile.path;
      }
      
      final savedIncident = incident.copyWith(
        photo: photoPath, // Stocker le chemin local de la photo (null sur web)
        audioFile: audioPath // Stocker le chemin du fichier audio si disponible
      );
      
      await _localDb.insertIncident(savedIncident);
      _incidents.insert(0, savedIncident);
      notifyListeners();
      return true;
    } catch (e) {
      print('Create incident error: $e');
      return false;
    }
  }
  
  // Vérifier si nous sommes connectés à Internet
  bool _isConnected() {
    // Si nous sommes en mode hors ligne connu, retourner false
    if (_isOfflineMode) {
      return false;
    }
    
    // Sinon, supposer que nous sommes en ligne et laisser l'API gérer les erreurs
    return true;
  }
  
  // Démarrer un timer pour synchroniser périodiquement les incidents
  void _startSyncTimer() {
    // Annuler le timer existant s'il y en a un
    _syncTimer?.cancel();
    
    // Créer un nouveau timer qui essaie de synchroniser toutes les 30 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isSyncing && unsyncedIncidents.isNotEmpty && !_isOfflineMode) {
        try {
          await syncIncidents();
          
          // Si tous les incidents sont synchronisés, arrêter le timer
          if (unsyncedIncidents.isEmpty) {
            timer.cancel();
            _syncTimer = null;
          }
        } catch (e) {
          print('Auto-sync error: $e');
          // Continuer à essayer
        }
      }
    });
  }

  // Synchroniser les incidents stockés localement
  Future<void> syncIncidents() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      final unsyncedIncidents = await _localDb.getUnsyncedIncidents();
      
      if (unsyncedIncidents.isEmpty) {
        _isSyncing = false;
        notifyListeners();
        return;
      }
      
      // Keep track of successfully synced incidents
      List<String> syncedLocalIds = [];
      
      for (var incident in unsyncedIncidents) {
        try {
          if (incident.localId != null) {
            // Try to sync each incident individually
            await _apiService.syncSingleIncident(incident);
            syncedLocalIds.add(incident.localId!);
            
            // Update sync status in local database
            await _localDb.updateIncidentSyncStatus(incident.localId!);
          }
        } catch (e) {
          print('Error syncing incident ${incident.localId}: $e');
          // Continue with next incident
        }
      }
      
      // If we're showing only offline incidents, remove the synced ones from our list
      if (_showOnlyOffline && syncedLocalIds.isNotEmpty) {
        _incidents.removeWhere((incident) => 
          incident.localId != null && syncedLocalIds.contains(incident.localId!)
        );
      } else {
        // Otherwise, update the status
        for (int i = 0; i < _incidents.length; i++) {
          final incident = _incidents[i];
          if (incident.localId != null && syncedLocalIds.contains(incident.localId!)) {
            _incidents[i] = incident.copyWith(isSynced: true);
          }
        }
      }
      
      // Reload if needed to get the server-assigned IDs
      await loadIncidents();
      
    } catch (e) {
      print('Sync error: $e');
      _error = 'Erreur lors de la synchronisation.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  // Supprimer un incident
  Future<bool> deleteIncident(Incident incident) async {
    try {
      if (incident.id != null) {
        // TODO: Implémenter la suppression via API si nécessaire
      }
      
      if (incident.localId != null) {
        await _localDb.deleteIncident(incident.id!);
      }
      
      _incidents.removeWhere((i) => 
        (incident.id != null && i.id == incident.id) || 
        (incident.localId != null && i.localId == incident.localId)
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Impossible de supprimer l\'incident.';
      notifyListeners();
      return false;
    }
  }
}