import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import '../../models/incident.dart';
import 'dart:io';
import '../../services/api_service.dart';

class IncidentDetailsScreen extends StatefulWidget {
  final Incident incident;

  const IncidentDetailsScreen({
    Key? key,
    required this.incident,
  }) : super(key: key);

  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _initTts();
    // Debug print to help diagnose image issues
    print('Incident photo: ${widget.incident.photo}');
    print('Incident photoUrl: ${widget.incident.photoUrl}');
    print('Is synced: ${widget.incident.isSynced}');
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('fr-FR');
    await _flutterTts.setSpeechRate(0.5);
    
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  Future<void> _speak() async {
    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
      });
      await _flutterTts.speak(widget.incident.description);
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.incident.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo de l'incident
            _buildIncidentImage(),
            
            // Informations générales
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type d'incident et statut
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildChip(
                        widget.incident.incidentTypeLabel,
                        _getIncidentTypeColor(widget.incident.incidentType),
                      ),
                      _buildChip(
                        widget.incident.statusLabel,
                        _getStatusColor(widget.incident.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Date de création
                  if (widget.incident.createdAt != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date de signalement'),
                      subtitle: Text(_dateFormat.format(widget.incident.createdAt!)),
                    ),
                  
                  // Utilisateur
                  if (widget.incident.userUsername != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person),
                      title: const Text('Signalé par'),
                      subtitle: Text(widget.incident.userUsername!),
                    ),
                  
                  // Description
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Bouton de lecture vocale si description par voix
                  if (widget.incident.isVoiceDescription)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
                        onPressed: _speak,
                        tooltip: _isPlaying ? 'Arrêter la lecture' : 'Lire la description',
                      ),
                    ),
                  
                  Text(widget.incident.description),
                  const SizedBox(height: 24),
                  
                  // Localisation
                  const Text(
                    'Localisation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Affichage des coordonnées
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5), // Grey 100 color
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E0E0)), // Grey 300 color
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFF44336)), // Red color
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Coordonnées GPS',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Latitude: ${widget.incident.latitude.toStringAsFixed(6)}',
                                  ),
                                  Text(
                                    'Longitude: ${widget.incident.longitude.toStringAsFixed(6)}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.incident.address != null && widget.incident.address!.isNotEmpty) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.home, color: Color(0xFF2196F3)), // Blue color
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Adresse',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(widget.incident.address!),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
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

  // Méthode améliorée pour construire l'image de l'incident
  Widget _buildIncidentImage() {
    // Cas 1: Pas d'image
    if (widget.incident.photo == null) {
      return Container(
        width: double.infinity,
        height: 250,
        color: const Color(0xFFE0E0E0),
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            size: 80,
            color: Color(0xFF9E9E9E),
          ),
        ),
      );
    }
    
    // Cas 2: Si photoUrl n'est pas null, utiliser directement cette URL
    if (widget.incident.photoUrl != null) {
      return Image.network(
        widget.incident.photoUrl!,
        width: double.infinity,
        height: 250,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print("Error loading image from URL: $error");
          return _buildImageErrorPlaceholder();
        },
      );
    }
    
    // Cas 3: Sur le web, mieux gérer les cas où la photo pourrait être une URL ou un chemin
    if (kIsWeb) {
      if (widget.incident.photo!.startsWith('http://') || widget.incident.photo!.startsWith('https://')) {
        return Image.network(
          widget.incident.photo!,
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print("Error loading web image: $error");
            return _buildImageErrorPlaceholder();
          },
        );
      } else {
        // Tentative de construire une URL à partir du chemin
        final url = '${ApiService.mediaUrl}/${widget.incident.photo!}';
        return Image.network(
          url,
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print("Error loading constructed URL: $error");
            return _buildImageErrorPlaceholder();
          },
        );
      }
    }
    
    // Cas 4: Sur mobile, utiliser le chemin du fichier local
    try {
      return Image.file(
        File(widget.incident.photo!),
        width: double.infinity,
        height: 250,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print("Error loading file: $error");
          // Si l'image locale ne peut pas être chargée, essayer l'URL du serveur
          if (widget.incident.isSynced) {
            final url = '${ApiService.mediaUrl}/${widget.incident.photo!}';
            return Image.network(
              url,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildImageErrorPlaceholder(),
            );
          }
          return _buildImageErrorPlaceholder();
        },
      );
    } catch (e) {
      print("Exception when creating image: $e");
      // Fallback pour tout autre cas
      return _buildImageErrorPlaceholder();
    }
  }
  
  // Widget de placeholder en cas d'erreur de chargement d'image
  Widget _buildImageErrorPlaceholder() {
    return Container(
      width: double.infinity,
      height: 250,
      color: const Color(0xFFE0E0E0), // Grey 300 color
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 80,
              color: Color(0xFF9E9E9E), // Grey color
            ),
            SizedBox(height: 8),
            Text(
              "Impossible de charger l'image",
              style: TextStyle(color: Color(0xFF9E9E9E)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }

  Color _getIncidentTypeColor(String incidentType) {
    switch (incidentType) {
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
    switch (status) {
      case 'new':
        return const Color(0xFFF44336); // Red color
      case 'in_progress':
        return const Color(0xFFFF9800); // Orange color
      case 'resolved':
        return const Color(0xFF4CAF50); // Green color
      default:
        return const Color(0xFF9E9E9E); // Grey color
    }
  }
}