import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/incident.dart';
import '../services/api_service.dart';

class IncidentCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback onTap;
  
  const IncidentCard({
    Key? key,
    required this.incident,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo de l'incident
            if (incident.photo != null)
              _buildIncidentImage(),
            
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et type d'incident
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          incident.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getIncidentTypeColor(incident.incidentType),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          incident.incidentType,
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF), // White color
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Description
                  const SizedBox(height: 8),
                  Text(
                    incident.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF616161), // Grey 700 color
                    ),
                  ),
                  
                  // Date et statut
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (incident.createdAt != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Color(0xFF9E9E9E), // Grey color
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateFormat.format(incident.createdAt!),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9E9E9E), // Grey color
                              ),
                            ),
                          ],
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(incident.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 8,
                              color: Color(0xFFFFFFFF), // White color
                            ),
                            const SizedBox(width: 4),
                            Text(
                              incident.status,
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF), // White color
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Indicateur de synchronisation
                  if (!incident.isSynced)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.sync_problem,
                            size: 16,
                            color: Color(0xFFFF9800), // Orange color
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Non synchronisé',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF9800), // Orange color
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Méthode pour construire l'image de l'incident en fonction de la plateforme
  Widget _buildIncidentImage() {
    // Cas 1: Image synchronisée depuis le serveur
    if (incident.isSynced && incident.photo != null && incident.photo!.startsWith('/')) {
      return Image.network(
        incident.photoUrl ?? '${ApiService.mediaUrl}${incident.photo}',
        width: double.infinity,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageErrorPlaceholder();
        },
      );
    }
    
    // Cas 2: Sur le web, utiliser une image de placeholder
    if (kIsWeb) {
      return Image.network(
        incident.photoUrl ?? 'https://via.placeholder.com/400x120?text=Incident+Photo',
        width: double.infinity,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageErrorPlaceholder();
        },
      );
    }
    
    // Cas 3: Sur mobile, utiliser le chemin du fichier local
    return Image.file(
      File(incident.photo!),
      width: double.infinity,
      height: 120,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildImageErrorPlaceholder();
      },
    );
  }
  
  // Widget de placeholder en cas d'erreur de chargement d'image
  Widget _buildImageErrorPlaceholder() {
    return Container(
      width: double.infinity,
      height: 120,
      color: const Color(0xFFE0E0E0), // Grey 300 color
      child: const Icon(
        Icons.broken_image,
        size: 50,
        color: Color(0xFF9E9E9E), // Grey color
      ),
    );
  }

  Color _getIncidentTypeColor(String incidentType) {
    switch (incidentType.toLowerCase()) {
      case 'fire':
        return const Color(0xFFF44336); // Red color
      case 'accident':
        return const Color(0xFFFF9800); // Orange color
      case 'flood':
        return const Color(0xFF2196F3); // Blue color
      case 'infrastructure':
        return const Color(0xFFFFCA28); // Amber color
      default:
        return const Color(0xFF9C27B0); // Purple color
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return const Color(0xFF2196F3); // Blue color
      case 'in progress':
        return const Color(0xFFFF9800); // Orange color
      case 'resolved':
        return const Color(0xFF4CAF50); // Green color
      default:
        return const Color(0xFF9E9E9E); // Grey color
    }
  }
}