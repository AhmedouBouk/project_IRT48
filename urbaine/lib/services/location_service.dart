// lib/services/location_service.dart
import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();

  Future<LocationData> getCurrentLocation() async {
    print("LocationService: Début de getCurrentLocation");
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    try {
      // Vérifier si le service est activé
      print("LocationService: Vérification si le service de localisation est activé");
      serviceEnabled = await _location.serviceEnabled();
      print("LocationService: Service de localisation activé: $serviceEnabled");
      
      if (!serviceEnabled) {
        print("LocationService: Service de localisation désactivé, demande d'activation");
        serviceEnabled = await _location.requestService();
        print("LocationService: Résultat de la demande d'activation: $serviceEnabled");
        
        if (!serviceEnabled) {
          print("LocationService: Échec de l'activation du service de localisation");
          throw Exception('Les services de localisation sont désactivés.');
        }
      }

      // Vérifier les permissions
      print("LocationService: Vérification des permissions de localisation");
      permissionGranted = await _location.hasPermission();
      print("LocationService: État actuel des permissions: $permissionGranted");
      
      if (permissionGranted == PermissionStatus.denied) {
        print("LocationService: Permission refusée, demande de permission");
        permissionGranted = await _location.requestPermission();
        print("LocationService: Résultat de la demande de permission: $permissionGranted");
        
        if (permissionGranted != PermissionStatus.granted) {
          print("LocationService: Permission toujours refusée après demande");
          throw Exception('Les autorisations de localisation sont refusées');
        }
      }

      // Obtenir la localisation
      print("LocationService: Récupération de la position");
      final locationData = await _location.getLocation();
      print("LocationService: Position obtenue: ${locationData.latitude}, ${locationData.longitude}");
      
      return locationData;
    } catch (e) {
      print("LocationService: Erreur lors de la récupération de la position: $e");
      rethrow;
    }
  }

  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    print("LocationService: Obtention de l'adresse pour $latitude, $longitude");
    try {
      // Utilisez une API de geocoding comme Google Geocoding API
      // Pour cet exemple, on retourne simplement les coordonnées
      return "$latitude, $longitude";
    } catch (e) {
      print("LocationService: Erreur lors de la récupération de l'adresse: $e");
      return "$latitude, $longitude";
    }
  }
  
  // Méthode explicite pour demander la permission qui peut être appelée au démarrage
  Future<bool> requestLocationPermission() async {
    print("LocationService: Demande explicite de permission de localisation");
    try {
      final permissionStatus = await _location.requestPermission();
      print("LocationService: Résultat de la demande explicite: $permissionStatus");
      return permissionStatus == PermissionStatus.granted;
    } catch (e) {
      print("LocationService: Erreur lors de la demande explicite de permission: $e");
      return false;
    }
  }
}