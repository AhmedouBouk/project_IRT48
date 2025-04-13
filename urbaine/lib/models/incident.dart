import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';

class Incident {
  final int? id;
  final String? localId;
  final String incidentType;
  final String title;
  final String description;
  final String? photo;
  final String? audioFile; // Path to audio file for voice descriptions
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status;
  final bool isVoiceDescription;
  final String? userUsername;
  final bool isSynced;

  // Getter pour l'URL de la photo
  String? get photoUrl {
    if (photo == null) {
      return 'https://via.placeholder.com/400x250?text=No+Image';
    }
    
    // Si l'incident est synchronisé et que la photo commence par '/' ou 'incidents/'
    if (isSynced) {
      if (photo!.startsWith('/')) {
        return '${ApiService.mediaUrl}${photo}';
      } else if (photo!.startsWith('incidents/')) {
        return '${ApiService.mediaUrl}/${photo}';
      } else if (photo!.startsWith('http://') || photo!.startsWith('https://')) {
        return photo;
      }
    }
    
    // Pour les photos locales ou sur le web sans URL complète
    if (kIsWeb && (photo!.startsWith('http://') || photo!.startsWith('https://'))) {
      return photo;
    }
    
    // Pour les chemins de fichier locaux, on retourne null pour que la logique d'affichage s'en occupe
    return null;
  }

  Incident({
    this.id,
    this.localId,
    required this.incidentType,
    required this.title,
    required this.description,
    this.photo,
    this.audioFile,
    required this.latitude,
    required this.longitude,
    this.address,
    this.createdAt,
    this.updatedAt,
    this.status = 'new',
    this.isVoiceDescription = false,
    this.userUsername,
    this.isSynced = true,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'],
      localId: json['local_id'],
      incidentType: json['incident_type'],
      title: json['title'],
      description: json['description'],
      photo: json['photo'],
      audioFile: json['audio_file'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      status: json['status'] ?? 'new',
      isVoiceDescription: json['is_voice_description'] ?? false,
      userUsername: json['user_username'],
      isSynced: true,
    );
  }

  factory Incident.fromMap(Map<String, dynamic> map) {
    return Incident(
      id: map['id'],
      localId: map['local_id'],
      incidentType: map['incident_type'],
      title: map['title'],
      description: map['description'],
      photo: map['photo'],
      audioFile: map['audio_file'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      address: map['address'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      status: map['status'] ?? 'new',
      isVoiceDescription: map['is_voice_description'] == 1,
      userUsername: map['user_username'],
      isSynced: map['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'local_id': localId,
      'incident_type': incidentType,
      'title': title,
      'description': description,
      'photo': photo,
      'audio_file': audioFile,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': status,
      'is_voice_description': isVoiceDescription,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_id': localId,
      'incident_type': incidentType,
      'title': title,
      'description': description,
      'photo': photo,
      'audio_file': audioFile,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'status': status,
      'is_voice_description': isVoiceDescription ? 1 : 0,
      'user_username': userUsername,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Incident copyWith({
    int? id,
    String? localId,
    String? incidentType,
    String? title,
    String? description,
    String? photo,
    String? audioFile,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    bool? isVoiceDescription,
    String? userUsername,
    bool? isSynced,
  }) {
    return Incident(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      incidentType: incidentType ?? this.incidentType,
      title: title ?? this.title,
      description: description ?? this.description,
      photo: photo ?? this.photo,
      audioFile: audioFile ?? this.audioFile,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isVoiceDescription: isVoiceDescription ?? this.isVoiceDescription,
      userUsername: userUsername ?? this.userUsername,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'new':
        return 'Nouveau';
      case 'in_progress':
        return 'En cours';
      case 'resolved':
        return 'Résolu';
      default:
        return 'Inconnu';
    }
  }

  String get incidentTypeLabel {
    switch (incidentType) {
      case 'fire':
        return 'Incendie';
      case 'accident':
        return 'Accident';
      case 'flood':
        return 'Inondation';
      case 'infrastructure':
        return 'Problème d\'infrastructure';
      case 'other':
        return 'Autre';
      default:
        return 'Inconnu';
    }
  }
}