// api_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../models/user.dart';
import '../models/incident.dart';

class ApiService {
  static const int timeoutDuration = 10; // seconds
  
  static String get baseUrl {
    
      // Pour les émulateurs Android, utiliser localhost
      return 'http://192.168.101.13:8000/api/v1';
    
  }
  
  static String get mediaUrl {
    
      return 'http://192.168.101.13:8000';
    
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ---------- AUTH FLOW ---------- //

  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/token/');
    final body = jsonEncode({'username': username, 'password': password});
    final headers = {'Content-Type': 'application/json'};

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final tokens = jsonDecode(response.body);
      await _storage.write(key: 'access_token', value: tokens['access']);
      await _storage.write(key: 'refresh_token', value: tokens['refresh']);
      return tokens;
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: 'access_token');
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: 'refresh_token');
  }

  Future<void> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) throw Exception('No refresh token available');

    final url = Uri.parse('$baseUrl/token/refresh/');
    final body = jsonEncode({'refresh': refreshToken});
    final headers = {'Content-Type': 'application/json'};

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['access'] != null) {
        await _storage.write(key: 'access_token', value: data['access']);
      } else {
        throw Exception('Refresh token response invalid');
      }
    } else {
      throw Exception('Failed to refresh token: ${response.body}');
    }
  }

  /// Helper that automatically adds the bearer token and
  /// attempts a single refresh on 401 responses.
  Future<http.Response> _makeAuthorizedRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    dynamic body,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    // Vérifier d'abord la connectivité au serveur
    if (!await checkServerConnectivity()) {
      throw Exception('Server is not reachable');
    }
    final token = await getAccessToken();
    headers = headers ?? {};
    headers['Authorization'] = 'Bearer $token';

    // Basic flow for GET/POST requests
    // If you need multipart, handle it below
    if (method.toUpperCase() == 'GET' || method.toUpperCase() == 'POST') {
      late http.Response response;
      if (files != null) {
        // Use multipart if files are present
        final request = http.MultipartRequest(method, Uri.parse('$baseUrl/$endpoint'));
        request.headers.addAll(headers);
        if (fields != null) {
          request.fields.addAll(fields);
        }
        for (var f in files) {
          request.files.add(f);
        }
        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        final uri = Uri.parse('$baseUrl/$endpoint');
        if (method.toUpperCase() == 'GET') {
          response = await http.get(uri, headers: headers);
        } else {
          // POST
          if (body != null && body is String) {
            response = await http.post(uri, headers: headers, body: body);
          } else {
            response = await http.post(uri, headers: headers);
          }
        }
      }

      // If unauthorized, try refreshing and then re-request once
      if (response.statusCode == 401) {
        // Attempt refresh
        await refreshAccessToken();
        // Retry once with new token
        final newToken = await getAccessToken();
        headers['Authorization'] = 'Bearer $newToken';
        if (files != null) {
          // Re-do multipart request
          final request2 = http.MultipartRequest(method, Uri.parse('$baseUrl/$endpoint'));
          request2.headers.addAll(headers);
          if (fields != null) {
            request2.fields.addAll(fields);
          }
          for (var f in files) {
            request2.files.add(f);
          }
          final streamedResponse2 = await request2.send();
          response = await http.Response.fromStream(streamedResponse2);
        } else {
          // Re-do normal request
          final uri2 = Uri.parse('$baseUrl/$endpoint');
          if (method.toUpperCase() == 'GET') {
            response = await http.get(uri2, headers: headers);
          } else {
            response = await http.post(uri2, headers: headers, body: body);
          }
        }
      }
      return response;
    }

    throw UnimplementedError('Method $method not implemented in _makeAuthorizedRequest');
  }

  Future<User> getCurrentUser() async {
    final resp = await _makeAuthorizedRequest(method: 'GET', endpoint: 'users/me/');
    if (resp.statusCode == 200) {
      return User.fromJson(jsonDecode(resp.body));
    } else {
      throw Exception('Failed to get user profile: ${resp.statusCode} ${resp.body}');
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'username': username,
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'role': 'citizen',
    });

    final resp = await http.post(Uri.parse('$baseUrl/users/'), headers: headers, body: body);
    return (resp.statusCode == 201);
  }

  // ---------- INCIDENTS ---------- //

  Future<bool> checkServerConnectivity() async {
    try {
      // Try a simple GET request to the base URL to check if server is reachable
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: timeoutDuration));
      
      // Any response (even 404) means server is up
      return response.statusCode != 503 && response.statusCode != 504;
    } catch (e) {
      print('Server connectivity check failed: $e');
      return false;
    }
  }

  Future<List<Incident>> getIncidents() async {
    try {
      final response = await _makeAuthorizedRequest(
        method: 'GET',
        endpoint: 'incidents/',
      ).timeout(const Duration(seconds: timeoutDuration));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((json) => Incident.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load incidents: ${response.body}');
      }
    } catch (e) {
      print('Error getting incidents: $e');
      throw Exception('Failed to load incidents: $e');
    }
  }

  // Single create attempt
  Future<Incident> createIncident(Incident incident, XFile photoFile) async {
    final fields = {
      'incident_type': incident.incidentType,
      'title': incident.title,
      'description': incident.description,
      'latitude': incident.latitude.toString(),
      'longitude': incident.longitude.toString(),
      'is_voice_description': incident.isVoiceDescription.toString(),
      if (incident.address != null) 'address': incident.address!,
      if (incident.localId != null) 'local_id': incident.localId!,
    };

    // Build a file for the photo
    http.MultipartFile? photoMultipart;
    if (photoFile.path.isNotEmpty) {
      
        photoMultipart = await http.MultipartFile.fromPath('photo', photoFile.path);
      
    }

    final resp = await _makeAuthorizedRequest(
      method: 'POST',
      endpoint: 'incidents/',
      fields: fields,
      files: (photoMultipart != null) ? [photoMultipart] : null,
    );
    if (resp.statusCode == 201) {
      return Incident.fromJson(jsonDecode(resp.body));
    } else {
      throw Exception('Failed to create incident: ${resp.body}');
    }
  }

  // Bulk sync for offline incidents
  Future<List<Incident>> syncIncidents(List<Incident> localIncidents) async {
    try {
      // For incidents with photos, we need to handle them one by one
      List<Incident> syncedIncidents = [];
      List<Incident> failedIncidents = [];
      
      for (final incident in localIncidents) {
        try {
          // If the incident has a photo path, we need to upload it separately
          if (incident.photo != null && incident.photo!.isNotEmpty) {
            // Check if the photo file exists
            final file = File(incident.photo!);
            if (!await file.exists()) {
              print('Photo file not found: ${incident.photo}. Skipping photo upload.');
              // Create incident without photo
              final resp = await _makeAuthorizedRequest(
                method: 'POST',
                endpoint: 'incidents/',
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(incident.toJson()..remove('photo')),
              );
              
              if (resp.statusCode == 201) {
                syncedIncidents.add(Incident.fromJson(jsonDecode(resp.body)));
                continue;
              } else {
                failedIncidents.add(incident);
                print('Failed to sync incident without photo: ${resp.statusCode} ${resp.body}');
                continue;
              }
            }
            
            // Create a file from the photo path
            final photoFile = XFile(incident.photo!);
            final syncedIncident = await createIncident(incident, photoFile);
            syncedIncidents.add(syncedIncident);
          } else {
            // For incidents without photos, we can use the bulk sync
            final body = jsonEncode([incident.toJson()]);
            final resp = await _makeAuthorizedRequest(
              method: 'POST',
              endpoint: 'incidents/sync/',
              body: body,
              headers: {'Content-Type': 'application/json'},
            );

            if (resp.statusCode == 201) {
              final data = jsonDecode(resp.body) as List;
              if (data.isNotEmpty) {
                syncedIncidents.add(Incident.fromJson(data.first));
              }
            } else {
              failedIncidents.add(incident);
              print('Failed to sync incident: ${resp.statusCode} ${resp.body}');
            }
          }
        } catch (e) {
          failedIncidents.add(incident);
          print('Error syncing individual incident: $e');
        }
      }
      
      // If all incidents failed, throw an exception
      if (syncedIncidents.isEmpty && failedIncidents.isNotEmpty) {
        throw Exception('Failed to sync any incidents');
      }
      
      return syncedIncidents;
    } catch (e) {
      print('Error in syncIncidents: $e');
      throw Exception('Failed to sync incidents: $e');
    }
  }
}
