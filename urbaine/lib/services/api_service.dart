import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../models/user.dart';
import '../models/incident.dart';

class ApiService {
  // Définir les URLs en fonction de la plateforme
  static String get baseUrl {
    if (kIsWeb) {
      // Sur le web, utiliser l'adresse IP ou le nom d'hôte réel du serveur
      return 'http://192.168.101.13:8000/api/v1';
    } else {
      // Pour les émulateurs Android, utiliser localhost
      return 'http://192.168.101.13:8000/api/v1';
    }
  }
  
  static String get mediaUrl {
    if (kIsWeb) {
      return 'http://192.168.101.13:8000';
    } else {
      return 'http://192.168.101.13:8000';
    }
  }
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Auth endpoints
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      print('Tentative de connexion avec: $username');
      
      final response = await http.post(
        Uri.parse('$baseUrl/token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      print('Statut de la réponse: ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');
      
      if (response.statusCode == 200) {
        final tokens = jsonDecode(response.body);
        await _storage.write(key: 'access_token', value: tokens['access']);
        await _storage.write(key: 'refresh_token', value: tokens['refresh']);
        return tokens;
      } else {
        throw Exception('Failed to login: ${response.body}');
      }
    } catch (e) {
      print('Erreur lors de la connexion: $e');
      throw Exception('Failed to login: $e');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<User> getCurrentUser() async {
    final token = await getAccessToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('API request timed out');
      });

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to get user profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting user profile: $e');
      throw Exception('Failed to get user profile: $e');
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'role': 'citizen',
      }),
    );

    return response.statusCode == 201;
  }

  // Incidents endpoints
  Future<List<Incident>> getIncidents() async {
    final token = await getAccessToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/incidents/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('API request timed out');
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Incident.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load incidents: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading incidents: $e');
      throw Exception('Failed to load incidents: $e');
    }
  }

  Future<Incident> createIncident(Incident incident, XFile photoFile) async {
    final token = await getAccessToken();
    
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/incidents/'),
    );
    
    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });
    
    request.fields.addAll({
      'incident_type': incident.incidentType,
      'title': incident.title,
      'description': incident.description,
      'latitude': incident.latitude.toString(),
      'longitude': incident.longitude.toString(),
      'is_voice_description': incident.isVoiceDescription.toString(),
      if (incident.address != null) 'address': incident.address!,
      if (incident.localId != null) 'local_id': incident.localId!,
    });
    
    // Gestion différente des fichiers pour le web et mobile
    if (kIsWeb) {
      // Sur le web, nous devons lire les bytes du fichier
      final bytes = await photoFile.readAsBytes();
      
      // Déterminer le type MIME basé sur l'extension du fichier
      String mimeType = 'image/jpeg'; // Par défaut
      final ext = path.extension(photoFile.name).toLowerCase();
      if (ext == '.png') {
        mimeType = 'image/png';
      } else if (ext == '.gif') {
        mimeType = 'image/gif';
      }
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: photoFile.name,
          contentType: MediaType.parse(mimeType),
        ),
      );
    } else {
      // Sur mobile, nous pouvons utiliser le chemin du fichier
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          photoFile.path,
        ),
      );
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 201) {
      return Incident.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create incident: ${response.body}');
    }
  }

  // Synchronisation d'un seul incident offline
  Future<Incident> syncSingleIncident(Incident incident) async {
    final token = await getAccessToken();
    
    // Si l'incident n'a pas de photo ou si nous sommes sur le web sans photo locale
    if (incident.photo == null || (kIsWeb && !incident.photo!.startsWith('http'))) {
      // Sync sans photo
      final response = await http.post(
        Uri.parse('$baseUrl/incidents/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(incident.toJson()),
      );
      
      if (response.statusCode == 201) {
        return Incident.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to sync incident: ${response.body}');
      }
    } else {
      // Sync avec photo
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/incidents/'),
      );
      
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });
      
      request.fields.addAll({
        'incident_type': incident.incidentType,
        'title': incident.title,
        'description': incident.description,
        'latitude': incident.latitude.toString(),
        'longitude': incident.longitude.toString(),
        'is_voice_description': incident.isVoiceDescription.toString(),
        if (incident.address != null) 'address': incident.address!,
        if (incident.localId != null) 'local_id': incident.localId!,
      });
      
      // Ajouter la photo
      if (!kIsWeb) {
        try {
          final file = File(incident.photo!);
          if (await file.exists()) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'photo',
                incident.photo!,
              ),
            );
          }
        } catch (e) {
          print('Error attaching photo: $e');
          // Continue without photo if there's an error
        }
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201) {
        return Incident.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to sync incident with photo: ${response.body}');
      }
    }
  }

  Future<List<Incident>> syncIncidents(List<Incident> localIncidents) async {
    final token = await getAccessToken();
    final response = await http.post(
      Uri.parse('$baseUrl/incidents/sync/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(
        localIncidents.map((incident) => incident.toJson()).toList(),
      ),
    );

    if (response.statusCode == 201) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Incident.fromJson(json)).toList();
    } else {
      throw Exception('Failed to sync incidents');
    }
  }
}