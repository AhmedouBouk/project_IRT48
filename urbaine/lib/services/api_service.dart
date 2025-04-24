// api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../models/incident.dart';
import '../models/user.dart';

class ApiService {
  static const int timeoutDuration = 20; // seconds - increased for better reliability
  static const int retryCount = 2; // Number of retries for network requests
  
  static String get baseUrl {
    
      // Pour les émulateurs Android, utiliser localhost
      return 'http://192.168.101.18:8000/api/v1';
    
  }
  
  static String get mediaUrl {
    
      return 'http://192.168.101.18:8000';
    
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Cache tokens in memory for better performance
  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  DateTime? _tokenExpiryTime;

  // ---------- AUTH FLOW ---------- //

  Future<bool> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/token/');
    final body = jsonEncode({
      'username': username,
      'password': password,
    });
    final headers = {'Content-Type': 'application/json'};

    try {
      print('Attempting login for user: $username');
      final response = await http.post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: timeoutDuration));

      print('Login response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Save tokens
        _cachedAccessToken = data['access'];
        _cachedRefreshToken = data['refresh'];
        _tokenExpiryTime = DateTime.now().add(const Duration(hours: 23));
        
        print('Saving tokens to secure storage');
        await _storage.write(key: 'auth_token', value: data['access']);
        await _storage.write(key: 'refresh_token', value: data['refresh']);
        
        print('Login successful');
        return true;
      } else {
        print('Login failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    // Clear cache
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _tokenExpiryTime = null;
    
    // Clear secure storage
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
    print('Tokens cleared from secure storage');
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    _cachedAccessToken = await _storage.read(key: 'auth_token');
    return _cachedAccessToken;
  }

  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    _cachedRefreshToken = await _storage.read(key: 'refresh_token');
    return _cachedRefreshToken;
  }

  Future<bool> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      print('No refresh token available');
      // Check if we have a cached access token already
      final accessToken = await getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        print('Using existing access token since no refresh token is available');
        return true; // We still have a potentially valid access token
      }
      return false;
    }

    // First check connectivity to avoid timeout errors
    try {
      final isConnected = await fastConnectivityCheck();
      if (!isConnected) {
        print('Cannot refresh token - no network connectivity');
        return false;
      }
    } catch (e) {
      print('Error checking connectivity during token refresh: $e');
      // Continue anyway, the http request will fail if there's truly no connectivity
    }

    final url = Uri.parse('$baseUrl/token/refresh/');
    final body = jsonEncode({'refresh': refreshToken});
    final headers = {'Content-Type': 'application/json'};

    try {
      print('Attempting to refresh token with refresh token: ${refreshToken.length > 10 ? refreshToken.substring(0, 10) + '...' : 'short token'}');
      final response = await http.post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: timeoutDuration));
      
      print('Token refresh response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access'] != null) {
          _cachedAccessToken = data['access']; // Update cache
          await _storage.write(key: 'access_token', value: data['access']);
          
          // Set token expiry time (typically JWT tokens expire in 24 hours)
          _tokenExpiryTime = DateTime.now().add(const Duration(hours: 23));
          print('Token refreshed successfully');
          return true;
        } else {
          print('Refresh token response invalid');
          return false;
        }
      } else {
        // Clear cache on error
        print('Failed to refresh token: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      // Clear cache on error
      print('Error refreshing token: $e');
      return false;
    }
  }

  /// Check if the current token is expired or about to expire
  Future<bool> isTokenExpired() async {
    // If we don't have an expiry time or token, consider it expired
    if (_tokenExpiryTime == null || _cachedAccessToken == null) {
      return true;
    }
    
    // If token expires in less than 5 minutes, consider it expired
    return DateTime.now().isAfter(_tokenExpiryTime!.subtract(const Duration(minutes: 5)));
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
    // Quick connectivity check before attempting any token operations
    final isConnected = await fastConnectivityCheck();
    if (!isConnected) {
      throw Exception('No network connectivity');
    }
  
    // Check if token is expired and refresh proactively if needed
    if (await isTokenExpired()) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        print('Token refreshed proactively');
      } else {
        print('Failed to refresh token proactively');
      }
    }
    
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      // Try one more refresh attempt
      final refreshed = await refreshAccessToken();
      if (!refreshed) {
        throw Exception('No access token available after refresh attempt');
      }
      // Get the new token after refresh
      final newAccessToken = await getAccessToken();
      if (newAccessToken == null) {
        throw Exception('No access token available');
      }
    }

    final url = Uri.parse('$baseUrl/$endpoint');
    final requestHeaders = {
      'Authorization': 'Bearer $accessToken',
      ...?headers,
    };

    http.Response? response;
    Exception? lastException;
    
    // Implement retry logic
    for (int attempt = 0; attempt <= retryCount; attempt++) {
      try {
        if (attempt > 0) {
          print('Retry attempt $attempt for $method $endpoint');
          // Add exponential backoff delay for retries
          await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
        }
        
        if (fields != null || files != null) {
          // Handle multipart requests
          final request = http.MultipartRequest(method, url);
          request.headers.addAll(requestHeaders);
          
          if (fields != null) {
            request.fields.addAll(fields);
          }
          
          if (files != null) {
            for (var file in files) {
              request.files.add(file);
            }
          }
          
          print('Sending $method request to $endpoint (multipart)');
          final streamedResponse = await request.send()
              .timeout(const Duration(seconds: timeoutDuration));
          response = await http.Response.fromStream(streamedResponse);
        } else {
          // Handle regular requests
          print('Sending $method request to $endpoint');
          switch (method) {
            case 'GET':
              response = await http.get(url, headers: requestHeaders)
                  .timeout(const Duration(seconds: timeoutDuration));
              break;
            case 'POST':
              response = await http.post(url, headers: requestHeaders, body: body)
                  .timeout(const Duration(seconds: timeoutDuration));
              break;
            case 'PUT':
              response = await http.put(url, headers: requestHeaders, body: body)
                  .timeout(const Duration(seconds: timeoutDuration));
              break;
            case 'DELETE':
              response = await http.delete(url, headers: requestHeaders)
                  .timeout(const Duration(seconds: timeoutDuration));
              break;
            default:
              throw Exception('Unsupported HTTP method: $method');
          }
        }
        
        print('Response from $endpoint: ${response.statusCode}');

        // If unauthorized, try to refresh the token and retry once
        if (response.statusCode == 401) {
          if (attempt < retryCount) { // Only try to refresh if we have retries left
            final refreshed = await refreshAccessToken();
            if (refreshed) {
              print('Token refreshed successfully after 401');
              
              // Get the new token
              final newToken = await getAccessToken();
              if (newToken != null) {
                // Update the authorization header for next retry
                requestHeaders['Authorization'] = 'Bearer $newToken';
                
                // Continue to next retry attempt with new token
                continue;
              } else {
                print('Failed to get new access token after refresh');
              }
            } else {
              print('Token refresh failed');
            }
          }
        }
        
        // If we got a response (even an error response), return it
        return response;
      } catch (e) {
        lastException = Exception('API request failed (attempt ${attempt+1}/$retryCount): $e');
        print(lastException);
        
        // If this was the last attempt, throw the exception
        if (attempt == retryCount) {
          throw lastException;
        }
        // Otherwise continue to next retry attempt
      }
    }
    
    // This should never happen due to the for loop structure, but to satisfy Dart's null safety:
    throw lastException ?? Exception('Unknown error in API request');
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

  // Cache for connectivity status to avoid too frequent checks
  DateTime? _lastSuccessfulConnectivityCheck;
  
  // Optimized connectivity check that uses cached result if recent
  Future<bool> fastConnectivityCheck() async {
    // If we had a successful check in the last 30 seconds, consider still connected
    if (_lastSuccessfulConnectivityCheck != null && 
        DateTime.now().difference(_lastSuccessfulConnectivityCheck!).inSeconds < 30) {
      return true;
    }
    
    // Otherwise do a full check
    return checkServerConnectivity();
  }

  Future<bool> checkServerConnectivity() async {
    try {
      // First check if we have network connectivity at all
      try {
        var connectivityResult = await (Connectivity().checkConnectivity());
        if (connectivityResult == ConnectivityResult.none) {
          print('No network connectivity');
          return false;
        }
      } catch (e) {
        print('Error checking connectivity: $e');
        // Continue anyway in case the connectivity plugin fails
      }
      
      // Try the token endpoint with POST
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/token/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': 'test', 'password': 'test'}),
        ).timeout(const Duration(seconds: 3));
        
        // Even a 401 response means the server is up
        if (response.statusCode != 404) {
          _lastSuccessfulConnectivityCheck = DateTime.now();
          return true;
        }
      } catch (e) {
        // Try another endpoint as fallback
      }
      
      // Try the incidents endpoint with GET as fallback
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/incidents/'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 3));
        
        // Even a 401 response means the server is up
        if (response.statusCode != 404) {
          _lastSuccessfulConnectivityCheck = DateTime.now();
          return true;
        }
      } catch (e) {
        // Silent fail
      }
      
      // If all else fails, just try to make a simple request to the base URL
      try {
        final baseUrlResponse = await http.get(
          Uri.parse(baseUrl),
        ).timeout(const Duration(seconds: 3));
        
        if (baseUrlResponse.statusCode != 404) {
          _lastSuccessfulConnectivityCheck = DateTime.now();
          return true;
        }
      } catch (e) {
        // All connectivity checks failed
      }
      
      return false;
    } catch (e) {
      print('Server connectivity check: FAILED with $e');
      return false;
    }
  }

  Future<List<Incident>> getIncidents() async {
    try {
      final resp = await _makeAuthorizedRequest(method: 'GET', endpoint: 'incidents/');
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        return data.map((item) => Incident.fromJson(item)).toList();
      } else if (resp.statusCode == 401) {
        // Authentication issue, return empty list instead of throwing exception
        print('Authentication issue when loading incidents: ${resp.statusCode}');
        return [];
      } else {
        print('Failed to load incidents: ${resp.statusCode} ${resp.body}');
        return [];
      }
    } catch (e) {
      print('Error loading incidents: $e');
      return [];
    }
  }

  // Single create attempt
  Future<Incident> createIncident(Incident incident, XFile? photo) async {
    final fields = {
      'incident_type': incident.incidentType,
      'title': incident.title,
      'description': incident.description,
      'latitude': incident.latitude.toString(),
      'longitude': incident.longitude.toString(),
      'is_voice_description': incident.isVoiceDescription.toString(),
    };

    if (incident.address != null) {
      fields['address'] = incident.address!;
    }
    
    if (incident.localId != null) {
      fields['local_id'] = incident.localId!;
    }

    http.MultipartFile? photoMultipart;
    if (photo != null && photo.path.isNotEmpty) {
      try {
        if (await File(photo.path).exists()) {
          photoMultipart = await http.MultipartFile.fromPath(
            'photo',
            photo.path,
            filename: path.basename(photo.path),
          );
          print('Photo file prepared for upload: ${photo.path}');
        } else {
          print('Photo file does not exist: ${photo.path}');
        }
      } catch (e) {
        print('Error reading photo file: $e');
      }
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
      if (localIncidents.isEmpty) {
        print('No incidents to sync');
        return [];
      }
      
      print('Starting sync of ${localIncidents.length} incidents');
      
      // Check connectivity before attempting sync
      final isConnected = await checkServerConnectivity();
      if (!isConnected) {
        print('Cannot sync incidents: device is offline');
        throw Exception('Cannot sync incidents: device is offline');
      }
      
      // For incidents with photos, we need to handle them one by one
      List<Incident> syncedIncidents = [];
      List<Incident> failedIncidents = [];
      
      // Group incidents by those with and without photos for more efficient processing
      final incidentsWithPhotos = localIncidents.where((i) => 
          i.photo != null && i.photo!.isNotEmpty).toList();
      final incidentsWithoutPhotos = localIncidents.where((i) => 
          i.photo == null || i.photo!.isEmpty).toList();
      
      print('Incidents with photos: ${incidentsWithPhotos.length}');
      print('Incidents without photos: ${incidentsWithoutPhotos.length}');
      
      // First sync incidents without photos (faster and can be done in bulk)
      if (incidentsWithoutPhotos.isNotEmpty) {
        try {
          print('Syncing ${incidentsWithoutPhotos.length} incidents without photos');
          // Process in smaller batches to avoid timeouts
          for (int i = 0; i < incidentsWithoutPhotos.length; i += 5) {
            final endIndex = (i + 5 < incidentsWithoutPhotos.length) 
                ? i + 5 
                : incidentsWithoutPhotos.length;
            final batch = incidentsWithoutPhotos.sublist(i, endIndex);
            
            try {
              final body = jsonEncode(batch.map((i) => i.toJson()).toList());
              final resp = await _makeAuthorizedRequest(
                method: 'POST',
                endpoint: 'incidents/sync/',
                body: body,
                headers: {'Content-Type': 'application/json'},
              );

              if (resp.statusCode == 201) {
                final data = jsonDecode(resp.body) as List;
                for (var item in data) {
                  syncedIncidents.add(Incident.fromJson(item));
                }
                print('Successfully synced batch of ${batch.length} incidents without photos');
              } else {
                print('Failed to sync batch: ${resp.statusCode} ${resp.body}');
                failedIncidents.addAll(batch);
              }
            } catch (e) {
              print('Error syncing batch: $e');
              failedIncidents.addAll(batch);
            }
          }
        } catch (e) {
          print('Error in bulk sync: $e');
          failedIncidents.addAll(incidentsWithoutPhotos);
        }
      }
      
      // Then sync incidents with photos one by one
      if (incidentsWithPhotos.isNotEmpty) {
        print('Syncing ${incidentsWithPhotos.length} incidents with photos');
        for (final incident in incidentsWithPhotos) {
          try {
            print('Syncing incident with photo: ${incident.title}');
            // Check if the photo file exists
            final file = File(incident.photo!);
            if (!await file.exists()) {
              print('Photo file not found: ${incident.photo}. Syncing without photo.');
              // Create incident without photo
              final resp = await _makeAuthorizedRequest(
                method: 'POST',
                endpoint: 'incidents/',
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(incident.toJson()..remove('photo')),
              );
              
              if (resp.statusCode == 201) {
                syncedIncidents.add(Incident.fromJson(jsonDecode(resp.body)));
                print('Successfully synced incident without photo (file not found)');
              } else {
                failedIncidents.add(incident);
                print('Failed to sync incident without photo: ${resp.statusCode} ${resp.body}');
              }
            } else {
              // Create a file from the photo path
              final photoFile = XFile(incident.photo!);
              final syncedIncident = await createIncident(incident, photoFile);
              syncedIncidents.add(syncedIncident);
              print('Successfully synced incident with photo');
            }
          } catch (e) {
            failedIncidents.add(incident);
            print('Error syncing individual incident with photo: $e');
          }
        }
      }
      
      print('Sync complete. Synced: ${syncedIncidents.length}, Failed: ${failedIncidents.length}');
      
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
