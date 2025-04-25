// api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/incident.dart';
import '../models/user.dart';
import 'compression_service.dart';
import 'network_info_service.dart';
import 'conflict_resolution_service.dart';

class ApiService {
  static const int timeoutDuration = 20; // seconds - increased for better reliability
  static const int retryCount = 2; // Number of retries for network requests
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _syncStatusKey = 'sync_status';
  
  // Network and conflict resolution services
  final NetworkInfoService _networkInfo = NetworkInfoService();
  final ConflictResolutionService _conflictService = ConflictResolutionService();
  
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

    // Liste des fichiers multipart à envoyer
    List<http.MultipartFile> multipartFiles = [];

    // Traitement de la photo
    if (photo != null && photo.path.isNotEmpty) {
      try {
        if (await File(photo.path).exists()) {
          // Compress the image based on network conditions
          String photoPath = photo.path;
          
          // Only compress if it's not a web URL
          if (!photoPath.startsWith('http')) {
            // Check network type and apply appropriate compression
            await _networkInfo.refreshNetworkInfo();
            final networkType = _networkInfo.networkType;
            final connectionQuality = _networkInfo.connectionQuality;
            
            print('Network type: $networkType, Quality: $connectionQuality');
            
            // Determine compression quality based on connection
            int compressionQuality;
            if (_networkInfo.isLowBandwidth) {
              compressionQuality = CompressionService.lowQuality;
              print('Using low quality compression for slow connection');
            } else if (networkType == NetworkType.mobile) {
              compressionQuality = CompressionService.mediumQuality;
              print('Using medium quality compression for mobile data');
            } else {
              compressionQuality = CompressionService.highQuality;
              print('Using high quality compression for WiFi');
            }
            
            // Compress the image
            photoPath = await CompressionService.compressImage(
              photo.path, 
              quality: compressionQuality
            );
          }
          
          final photoMultipart = await http.MultipartFile.fromPath(
            'photo',
            photoPath,
            filename: path.basename(photoPath),
          );
          multipartFiles.add(photoMultipart);
          print('Photo file prepared for upload: $photoPath');
        } else {
          print('Photo file does not exist: ${photo.path}');
        }
      } catch (e) {
        print('Error processing photo file: $e');
      }
    }

    // Traitement du fichier audio
    if (incident.audioFile != null && incident.audioFile!.isNotEmpty) {
      try {
        final audioFile = File(incident.audioFile!);
        if (await audioFile.exists()) {
          final audioMultipart = await http.MultipartFile.fromPath(
            'audio_file',
            incident.audioFile!,
            filename: path.basename(incident.audioFile!),
          );
          multipartFiles.add(audioMultipart);
          print('Audio file prepared for upload: ${incident.audioFile}');
        } else {
          print('Audio file does not exist: ${incident.audioFile}');
        }
      } catch (e) {
        print('Error processing audio file: $e');
      }
    }

    final resp = await _makeAuthorizedRequest(
      method: 'POST',
      endpoint: 'incidents/',
      fields: fields,
      files: multipartFiles.isNotEmpty ? multipartFiles : null,
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
        await _saveSyncStatus('success', 'No incidents to sync');
        return [];
      }
      
      print('Starting sync of ${localIncidents.length} incidents');
      await _saveSyncStatus('syncing', 'Starting sync process');
      
      // Check connectivity and network type before attempting sync
      await _networkInfo.refreshNetworkInfo();
      final isConnected = await checkServerConnectivity();
      if (!isConnected) {
        print('Cannot sync incidents: device is offline');
        await _saveSyncStatus('offline', 'Device is offline');
        throw Exception('Cannot sync incidents: device is offline');
      }
      
      // For incidents with photos, we need to handle them one by one
      List<Incident> syncedIncidents = [];
      List<Incident> failedIncidents = [];
      List<Incident> conflictedIncidents = [];
      
      // Group incidents by those with and without photos for more efficient processing
      final incidentsWithPhotos = localIncidents.where((i) => 
          i.photo != null && i.photo!.isNotEmpty).toList();
      final incidentsWithoutPhotos = localIncidents.where((i) => 
          i.photo == null || i.photo!.isEmpty).toList();
      
      print('Incidents with photos: ${incidentsWithPhotos.length}');
      print('Incidents without photos: ${incidentsWithoutPhotos.length}');
      
      // Get optimal batch size based on network conditions
      int batchSize = _networkInfo.isLowBandwidth ? 3 : 5;
      print('Using batch size of $batchSize based on network conditions');
      
      // First sync incidents without photos (faster and can be done in bulk)
      if (incidentsWithoutPhotos.isNotEmpty) {
        try {
          print('Syncing ${incidentsWithoutPhotos.length} incidents without photos');
          await _saveSyncStatus('syncing', 'Syncing incidents without photos');
          
          // Process in smaller batches to avoid timeouts
          for (int i = 0; i < incidentsWithoutPhotos.length; i += batchSize) {
            final endIndex = (i + batchSize < incidentsWithoutPhotos.length) 
                ? i + batchSize 
                : incidentsWithoutPhotos.length;
            final batch = incidentsWithoutPhotos.sublist(i, endIndex);
            
            try {
              // Check for conflicts before syncing
              await _checkForConflicts(batch, conflictedIncidents);
              
              // Remove conflicted incidents from the batch
              final nonConflictedBatch = batch.where(
                (incident) => !conflictedIncidents.any(
                  (conflicted) => conflicted.localId == incident.localId
                )
              ).toList();
              
              if (nonConflictedBatch.isEmpty) {
                print('All incidents in this batch have conflicts, skipping batch');
                continue;
              }
              
              final body = jsonEncode(nonConflictedBatch.map((i) => i.toJson()).toList());
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
                print('Successfully synced batch of ${nonConflictedBatch.length} incidents without photos');
                
                // Update sync progress
                final progress = (syncedIncidents.length + failedIncidents.length + conflictedIncidents.length) / 
                    localIncidents.length;
                await _saveSyncStatus('syncing', 'Syncing in progress', progress);
              } else {
                print('Failed to sync batch: ${resp.statusCode} ${resp.body}');
                failedIncidents.addAll(nonConflictedBatch);
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
        await _saveSyncStatus('syncing', 'Syncing incidents with photos');
        
        // Sort by file size if possible (smallest first for faster initial progress)
        incidentsWithPhotos.sort((a, b) {
          if (a.photo == null || b.photo == null) return 0;
          try {
            final fileA = File(a.photo!);
            final fileB = File(b.photo!);
            if (fileA.existsSync() && fileB.existsSync()) {
              return fileA.lengthSync().compareTo(fileB.lengthSync());
            }
          } catch (e) {
            // Ignore errors, just use original order
          }
          return 0;
        });
        
        for (final incident in incidentsWithPhotos) {
          try {
            print('Syncing incident with photo: ${incident.title}');
            
            // Check for conflicts
            bool hasConflict = false;
            try {
              hasConflict = await _checkIncidentForConflict(incident);
              if (hasConflict) {
                print('Conflict detected for incident ${incident.localId}, adding to conflicted list');
                conflictedIncidents.add(incident);
                continue;
              }
            } catch (e) {
              print('Error checking for conflicts: $e');
              // Continue with sync attempt even if conflict check fails
            }
            
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
            
            // Update sync progress
            final progress = (syncedIncidents.length + failedIncidents.length + conflictedIncidents.length) / 
                localIncidents.length;
            await _saveSyncStatus('syncing', 'Syncing in progress', progress);
          } catch (e) {
            failedIncidents.add(incident);
            print('Error syncing individual incident with photo: $e');
          }
        }
      }
      
      // Handle conflicts if any
      if (conflictedIncidents.isNotEmpty) {
        print('Resolving ${conflictedIncidents.length} conflicted incidents');
        await _saveSyncStatus('resolving_conflicts', 'Resolving conflicts');
        
        for (final incident in conflictedIncidents) {
          try {
            final resolvedIncident = await _resolveConflict(incident);
            if (resolvedIncident != null) {
              syncedIncidents.add(resolvedIncident);
              print('Successfully resolved and synced conflicted incident: ${incident.localId}');
            } else {
              failedIncidents.add(incident);
              print('Failed to resolve conflict for incident: ${incident.localId}');
            }
          } catch (e) {
            failedIncidents.add(incident);
            print('Error resolving conflict: $e');
          }
        }
      }
      
      print('Sync complete. Synced: ${syncedIncidents.length}, Failed: ${failedIncidents.length}, Conflicts: ${conflictedIncidents.length}');
      
      // Save last sync timestamp
      await _saveLastSyncTimestamp();
      
      // Update sync status based on results
      if (failedIncidents.isEmpty && conflictedIncidents.isEmpty) {
        await _saveSyncStatus('success', 'Sync completed successfully');
      } else if (syncedIncidents.isNotEmpty) {
        await _saveSyncStatus('partial', 'Some items failed to sync');
      } else {
        await _saveSyncStatus('error', 'Failed to sync any incidents');
      }
      
      // If all incidents failed, throw an exception
      if (syncedIncidents.isEmpty && (failedIncidents.isNotEmpty || conflictedIncidents.isNotEmpty)) {
        throw Exception('Failed to sync any incidents');
      }
      
      return syncedIncidents;
    } catch (e) {
      print('Error in syncIncidents: $e');
      await _saveSyncStatus('error', 'Sync error: ${e.toString()}');
      throw Exception('Failed to sync incidents: $e');
    }
  }

  // Check for conflicts before syncing
  Future<void> _checkForConflicts(List<Incident> incidents, List<Incident> conflictedIncidents) async {
    for (final incident in incidents) {
      try {
        if (await _checkIncidentForConflict(incident)) {
          conflictedIncidents.add(incident);
        }
      } catch (e) {
        print('Error checking for conflict: $e');
        // Continue with next incident
      }
    }
  }

  // Check if a single incident has a conflict with server version
  Future<bool> _checkIncidentForConflict(Incident incident) async {
    // Skip conflict check for new incidents
    if (incident.id == null) return false;
    
    try {
      final resp = await _makeAuthorizedRequest(
        method: 'GET',
        endpoint: 'incidents/${incident.id}/',
      );
      
      if (resp.statusCode == 200) {
        final serverIncident = Incident.fromJson(jsonDecode(resp.body));
        return _conflictService.hasConflict(incident, serverIncident);
      }
    } catch (e) {
      print('Error fetching server incident for conflict check: $e');
      // If we can't check, assume no conflict
    }
    
    return false;
  }

  // Resolve a conflict between local and server versions
  Future<Incident?> _resolveConflict(Incident localIncident) async {
    try {
      // Skip if no server ID
      if (localIncident.id == null) return null;
      
      // Get server version
      final resp = await _makeAuthorizedRequest(
        method: 'GET',
        endpoint: 'incidents/${localIncident.id}/',
      );
      
      if (resp.statusCode == 200) {
        final serverIncident = Incident.fromJson(jsonDecode(resp.body));
        
        // Resolve the conflict
        final resolvedIncident = await _conflictService.resolveIncidentConflict(
          localIncident, 
          serverIncident
        );
        
        // If the resolved version matches the server version, we're done
        if (resolvedIncident.title == serverIncident.title && 
            resolvedIncident.description == serverIncident.description) {
          return resolvedIncident;
        }
        
        // Otherwise, update the server with our resolved version
        final updateResp = await _makeAuthorizedRequest(
          method: 'PUT',
          endpoint: 'incidents/${localIncident.id}/',
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(resolvedIncident.toJson()),
        );
        
        if (updateResp.statusCode == 200) {
          return Incident.fromJson(jsonDecode(updateResp.body));
        } else {
          print('Failed to update server with resolved incident: ${updateResp.statusCode}');
          return null;
        }
      } else {
        print('Failed to get server incident: ${resp.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error resolving conflict: $e');
      return null;
    }
  }

  // Save the last successful sync timestamp
  Future<void> _saveLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      await prefs.setString(_lastSyncKey, now);
      print('Saved last sync timestamp: $now');
    } catch (e) {
      print('Error saving sync timestamp: $e');
    }
  }

  // Get the last successful sync timestamp
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_lastSyncKey);
      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }
    } catch (e) {
      print('Error getting sync timestamp: $e');
    }
    return null;
  }

  // Save sync status for persistence across app restarts
  Future<void> _saveSyncStatus(String status, String message, [double progress = 0.0]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusData = jsonEncode({
        'status': status,
        'message': message,
        'progress': progress,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_syncStatusKey, statusData);
      print('Saved sync status: $status - $message');
    } catch (e) {
      print('Error saving sync status: $e');
    }
  }

  // Get the current sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusJson = prefs.getString(_syncStatusKey);
      if (statusJson != null) {
        return jsonDecode(statusJson);
      }
    } catch (e) {
      print('Error getting sync status: $e');
    }
    return {
      'status': 'unknown',
      'message': '',
      'progress': 0.0,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
