import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/incident.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';

class IncidentProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalDatabase _localDb = LocalDatabase();
  final Uuid _uuid = const Uuid();
  
  List<Incident> _incidents = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  bool _showOnlyOffline = false;

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

  // Charger les incidents depuis l'API
  Future<void> loadIncidents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // D'abord, essayer de charger les incidents depuis l'API
      final apiIncidents = await _apiService.getIncidents();
      _incidents = apiIncidents;
      
      // Ensuite, ajouter les incidents stockés localement qui ne sont pas encore synchronisés
      final localIncidents = await _localDb.getUnsyncedIncidents();
      if (localIncidents.isNotEmpty) {
        _incidents.addAll(localIncidents);
        // Trier par date de création
        _incidents.sort((a, b) => 
          (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now())
        );
      }
      
      _error = null;
    } catch (e) {
      print('Error loading incidents: $e');
      // En cas d'erreur, charger uniquement depuis la base de données locale
      try {
        final localIncidents = await _localDb.getIncidents();
        _incidents = localIncidents;
      } catch (dbError) {
        print('Database error: $dbError');
        _error = 'Impossible de charger les incidents.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
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
      bool isOnline = true;
      
      try {
        final createdIncident = await _apiService.createIncident(
          incident, 
          photoFile
        );
        
        _incidents.insert(0, createdIncident);
        notifyListeners();
        return true;
      } catch (e) {
        print('API Error: $e');
        isOnline = false;
        // Si l'API échoue, enregistrer localement
      }
      
      if (!isOnline) {
        // Sur le web, nous ne pouvons pas stocker le chemin du fichier
        String? photoPath;
        if (!kIsWeb) {
          photoPath = photoFile.path;
        }
        
        final savedIncident = incident.copyWith(
          photo: photoPath // Stocker le chemin local de la photo (null sur web)
        );
        
        await _localDb.insertIncident(savedIncident);
        _incidents.insert(0, savedIncident);
        notifyListeners();
        return true;
      }
      
      return true;
    } catch (e) {
      print('Create incident error: $e');
      return false;
    }
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