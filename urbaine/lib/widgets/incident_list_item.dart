// lib/widgets/incident_list_item.dart
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/incident.dart';

/// Widget réutilisable pour afficher un incident dans une liste.
/// Utilisé par OfflineIncidentsScreen et IncidentHistoryScreen.
class IncidentListItem extends StatefulWidget {
  final Incident incident;
  final DateFormat dateFormat;
  final bool showSyncStatus;
  final List<Widget>? customActions;

  const IncidentListItem({
    super.key,
    required this.incident,
    required this.dateFormat,
    this.showSyncStatus = false,
    this.customActions,
  });

  @override
  State<IncidentListItem> createState() => _IncidentListItemState();
}

class _IncidentListItemState extends State<IncidentListItem> {
  // ────────────────────────── AUDIO ──────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  // ────────────────────────── UI ─────────────────────────────
  bool _expanded = false;

  // ────────────────────────── INIT / DISPOSE ────────────────
  @override
  void initState() {
    super.initState();

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ────────────────────────── UTILITY METHODS ─────────────────────
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // ────────────────────────── AUDIO PLAY ─────────────────────
  Future<void> _playAudio(String? path) async {
    if (path == null || path.isEmpty) {
      _showErrorSnackBar('Aucun fichier audio disponible');
      return;
    }

    // Log détaillé du chemin audio pour le débogage
    debugPrint('\n🎵 Tentative de lecture audio: $path');

    // Afficher une durée fictive pour la barre avant chargement réel
    if (_duration == Duration.zero) {
      setState(() => _duration = const Duration(seconds: 30));
    }

    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chargement de l\'audio...')),
    );

    try {
      // 1. Essayer de lire depuis une URL HTTP
      if (path.startsWith('http')) {
        debugPrint('🎵 Lecture depuis URL: $path');
        try {
          await _audioPlayer.play(UrlSource(path));
          setState(() => _isPlaying = true);
          return;
        } catch (e) {
          debugPrint('🎵 Erreur lors de la lecture depuis URL: $e');
          // Si l'URL échoue, continuer avec les autres méthodes
        }
      }
      
      // 2. Essayer le chemin original
      final file = File(path);
      if (await file.exists()) {
        debugPrint('🎵 Fichier trouvé au chemin original: $path');
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() => _isPlaying = true);
        return;
      }
      
      debugPrint('🎵 Fichier introuvable au chemin original: $path');
      
      // 3. Extraire le nom du fichier pour recherche
      final fileName = path.split('/').last;
      
      // 4. Essayer dans le répertoire des documents
      final docsDir = await getApplicationDocumentsDirectory();
      final docsPath = '${docsDir.path}/$fileName';
      final docsFile = File(docsPath);
      
      if (await docsFile.exists()) {
        debugPrint('🎵 Fichier trouvé dans les documents: $docsPath');
        await _audioPlayer.play(DeviceFileSource(docsPath));
        setState(() => _isPlaying = true);
        return;
      }
      
      // 5. Essayer dans le répertoire temporaire
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      final tempFile = File(tempPath);
      
      if (await tempFile.exists()) {
        debugPrint('🎵 Fichier trouvé dans le répertoire temporaire: $tempPath');
        
        // Copier vers le répertoire des documents pour une utilisation future
        try {
          await tempFile.copy(docsPath);
          debugPrint('🎵 Fichier copié vers les documents: $docsPath');
        } catch (e) {
          debugPrint('🎵 Erreur lors de la copie du fichier: $e');
        }
        
        await _audioPlayer.play(DeviceFileSource(tempPath));
        setState(() => _isPlaying = true);
        return;
      }
      
      // 6. Recherche avancée - parcourir tous les fichiers audio dans les documents
      try {
        final docFiles = docsDir.listSync();
        final audioFiles = docFiles.where((file) => 
            file.path.endsWith('.m4a') || 
            file.path.endsWith('.mp3') || 
            file.path.endsWith('.aac')
        ).toList();
        
        if (audioFiles.isNotEmpty) {
          // Chercher un fichier qui contient une partie du nom du fichier original
          final baseFileName = fileName.split('.').first;
          for (var file in audioFiles) {
            final currentFileName = file.path.split('/').last;
            if (currentFileName.contains(baseFileName) || 
                baseFileName.contains(currentFileName.split('.').first)) {
              debugPrint('🎵 Fichier audio similaire trouvé: ${file.path}');
              await _audioPlayer.play(DeviceFileSource(file.path));
              setState(() => _isPlaying = true);
              return;
            }
          }
          
          // Si aucun fichier correspondant n'est trouvé, utiliser le plus récent
          audioFiles.sort((a, b) => 
            File(b.path).statSync().modified.compareTo(File(a.path).statSync().modified)
          );
          
          debugPrint('🎵 Utilisation du fichier audio le plus récent: ${audioFiles.first.path}');
          await _audioPlayer.play(DeviceFileSource(audioFiles.first.path));
          setState(() => _isPlaying = true);
          return;
        }
      } catch (e) {
        debugPrint('🎵 Erreur lors de la recherche avancée: $e');
      }
      
      // 7. Si on arrive ici, aucun fichier audio n'a été trouvé
      _showErrorSnackBar('Fichier audio non trouvé');
    } catch (e) {
      debugPrint('🎵 ERREUR lecture audio: $e');
      _showErrorSnackBar('Erreur de lecture audio');
    }
  }

  // ────────────────────────── UI BUILDERS ─────────────────────
  Widget _buildAudioPlayer() {
    final audioFile = widget.incident.audioFile;
    
    if (audioFile == null || audioFile.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () => _playAudio(audioFile),
            ),
            Expanded(
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble(),
                onChanged: (value) {
                  final position = Duration(seconds: value.toInt());
                  _audioPlayer.seek(position);
                },
              ),
            ),
            Text(
              '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / '
              '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeIcon(String type) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getTypeColor(type),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getTypeIcon(type),
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildSyncBadge() {
    if (!widget.showSyncStatus) return const SizedBox.shrink();
    
    final synced = widget.incident.isSynced;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: synced ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        synced ? 'Synchronisé' : 'Non synchronisé',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final photoUrl = widget.incident.photoUrl;
    
    if (photoUrl == null || photoUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: () => _showFullImageDialog(photoUrl),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.only(right: 8),
        child: _buildImageContainer(photoUrl),
      ),
    );
  }

  Widget _buildExpandedDescription() {
    final description = widget.incident.description;
    
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text(
          'Description',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(description),
      ],
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'accident':
        return Colors.red;
      case 'travaux':
        return Colors.orange;
      case 'événement':
      case 'evenement':
        return Colors.blue;
      case 'autre':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'accident':
        return Icons.warning;
      case 'travaux':
        return Icons.construction;
      case 'événement':
      case 'evenement':
        return Icons.event;
      case 'autre':
        return Icons.info;
      default:
        return Icons.help;
    }
  }

  Widget _buildImageContainer(String photoUrl) {
    if (photoUrl.startsWith('http')) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Erreur de chargement d\'image: $error');
          return _buildBrokenImage();
        },
      );
    } else {
      return Image.file(
        File(photoUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Erreur de chargement d\'image locale: $error');
          return _buildBrokenImage();
        },
      );
    }
  }

  Widget _buildBrokenImage() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
        ),
      ),
    );
  }

  Future<void> _showFullImageDialog(String photoUrl) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Photo de l\'incident'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: photoUrl.startsWith('http')
                  ? Image.network(
                      photoUrl,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildBrokenImage();
                      },
                    )
                  : Image.file(
                      File(photoUrl),
                      errorBuilder: (context, error, stackTrace) {
                        return _buildBrokenImage();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final dateFormat = widget.dateFormat;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeIcon(incident.incidentType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                incident.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildSyncBadge(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Signalé le ${incident.createdAt != null ? dateFormat.format(incident.createdAt!) : "date inconnue"}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildThumbnail(),
                            Expanded(
                              child: Text(
                                incident.description ?? '',
                                maxLines: _expanded ? null : 2,
                                overflow: _expanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                _buildExpandedDescription(),
                _buildAudioPlayer(),
                if (widget.customActions != null) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: widget.customActions!,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
