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
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
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
      const SnackBar(
        content: Text('Chargement de l\'audio...'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      // Stratégie de lecture audio en cascade
      await _tryPlayAudioFromMultipleSources(path);
    } catch (e) {
      debugPrint('🎵 ERREUR lecture audio: $e');
      _showErrorSnackBar('Erreur de lecture audio');
    }
  }

  Future<void> _tryPlayAudioFromMultipleSources(String path) async {
    // 1. Essayer de lire depuis une URL HTTP
    if (path.startsWith('http')) {
      try {
        await _audioPlayer.play(UrlSource(path));
        setState(() => _isPlaying = true);
        return;
      } catch (e) {
        debugPrint('🎵 Erreur lors de la lecture depuis URL: $e');
      }
    }
    
    // 2. Essayer le chemin original
    final file = File(path);
    if (await file.exists()) {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _isPlaying = true);
      return;
    }
    
    // 3. Extraire le nom du fichier pour recherche
    final fileName = path.split('/').last;
    
    // 4. Essayer dans le répertoire des documents
    final docsDir = await getApplicationDocumentsDirectory();
    final docsPath = '${docsDir.path}/$fileName';
    final docsFile = File(docsPath);
    
    if (await docsFile.exists()) {
      await _audioPlayer.play(DeviceFileSource(docsPath));
      setState(() => _isPlaying = true);
      return;
    }
    
    // 5. Essayer dans le répertoire temporaire
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/$fileName';
    final tempFile = File(tempPath);
    
    if (await tempFile.exists()) {
      // Copier vers le répertoire des documents pour une utilisation future
      try {
        await tempFile.copy(docsPath);
      } catch (e) {
        debugPrint('🎵 Erreur lors de la copie du fichier: $e');
      }
      
      await _audioPlayer.play(DeviceFileSource(tempPath));
      setState(() => _isPlaying = true);
      return;
    }
    
    // 6. Recherche avancée - parcourir tous les fichiers audio dans les documents
    await _tryFindSimilarAudioFile(fileName, docsDir);
  }

  Future<void> _tryFindSimilarAudioFile(String fileName, Directory docsDir) async {
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
            await _audioPlayer.play(DeviceFileSource(file.path));
            setState(() => _isPlaying = true);
            return;
          }
        }
        
        // Si aucun fichier correspondant n'est trouvé, utiliser le plus récent
        audioFiles.sort((a, b) => 
          File(b.path).statSync().modified.compareTo(File(a.path).statSync().modified)
        );
        
        await _audioPlayer.play(DeviceFileSource(audioFiles.first.path));
        setState(() => _isPlaying = true);
        return;
      }
      
      // Si on arrive ici, aucun fichier audio n'a été trouvé
      _showErrorSnackBar('Fichier audio non trouvé');
    } catch (e) {
      debugPrint('🎵 Erreur lors de la recherche avancée: $e');
      _showErrorSnackBar('Erreur lors de la recherche du fichier audio');
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
        const Divider(height: 24),
        Row(
          children: [
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Theme.of(context).primaryColor,
                size: 32,
              ),
              onPressed: () => _playAudio(audioFile),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Expanded(
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble(),
                onChanged: (value) {
                  final position = Duration(seconds: value.toInt());
                  _audioPlayer.seek(position);
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ),
            Text(
              '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeIcon(String type) {
    final color = _getTypeColor(type);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
        color: synced ? Colors.green.shade600 : Colors.orange.shade600,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        synced ? 'Sync' : 'Non sync',
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
      child: Hero(
        tag: 'incident-photo-${widget.incident.id}',
        child: Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildImageContainer(photoUrl),
        ),
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
        const Divider(height: 24),
        const Text(
          'Description',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'accident':
        return Colors.red.shade700;
      case 'travaux':
        return Colors.orange.shade700;
      case 'événement':
      case 'evenement':
        return Colors.blue.shade700;
      case 'autre':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'accident':
        return Icons.warning_amber_rounded;
      case 'travaux':
        return Icons.construction;
      case 'événement':
      case 'evenement':
        return Icons.event_available;
      case 'autre':
        return Icons.info_outline;
      default:
        return Icons.help_outline;
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
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                    loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          );
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
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.grey,
        ),
      ),
    );
  }

  Future<void> _openInMaps(double lat, double lng) async {
    // Vérifier que les coordonnées sont valides
    if (lat == 0.0 && lng == 0.0) {
      if (!mounted) return;
      _showErrorSnackBar('Coordonnées GPS non disponibles');
      return;
    }
    
    // Utiliser une URL compatible avec plus d'applications
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        final success = await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
        );
        
        if (!success && mounted) {
          _showErrorSnackBar('Échec de l\'ouverture de Google Maps');
        }
      } else {
        if (!mounted) return;
        _showErrorSnackBar('Impossible d\'ouvrir Google Maps');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Erreur: $e');
    }
  }

  Future<void> _showFullImageDialog(String photoUrl) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Photo de l\'incident'),
              centerTitle: true,
              automaticallyImplyLeading: false,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Hero(
                  tag: 'incident-photo-${widget.incident.id}',
                  child: photoUrl.startsWith('http')
                      ? Image.network(
                          photoUrl,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildBrokenImage();
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        )
                      : Image.file(
                          File(photoUrl),
                          errorBuilder: (context, error, stackTrace) {
                            return _buildBrokenImage();
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.location_on, size: 16),
      label: const Text('Voir sur la carte'),
      onPressed: () => _openInMaps(widget.incident.latitude, widget.incident.longitude),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildIncidentMeta() {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 12,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            widget.incident.createdAt != null 
                ? widget.dateFormat.format(widget.incident.createdAt!)
                : "date inconnue",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip() {
    final type = widget.incident.incidentType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _getTypeColor(type).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: _getTypeColor(type),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section with title and sync badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeIcon(incident.incidentType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and sync badge
                        Row(
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
                            if (widget.showSyncStatus) ...[
                              const SizedBox(width: 4),
                              _buildSyncBadge(),
                            ],
                          ],
                        ),
                        
                        // Date and type
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: _buildIncidentMeta()),
                            const SizedBox(width: 4),
                            _buildTypeChip(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Content section
              const SizedBox(height: 8),
              if (incident.description != null && incident.description!.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (incident.photoUrl != null && incident.photoUrl!.isNotEmpty)
                      _buildThumbnail(),
                    Expanded(
                      child: Text(
                        incident.description!,
                        maxLines: _expanded ? null : 2,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[800],
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              // Expand indicator
              if (!_expanded && (incident.description?.length ?? 0) > 100)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _expanded = true;
                      });
                    },
                    child: const Text('Voir plus'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              
              // Expanded content
              if (_expanded) ...[
                if (incident.photoUrl != null && incident.photoUrl!.isNotEmpty && incident.description == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildThumbnail(),
                  ),
                _buildAudioPlayer(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLocationButton(),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                      onPressed: () {
                        setState(() {
                          _expanded = false;
                        });
                      },
                      tooltip: 'Réduire',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                if (widget.customActions != null && widget.customActions!.isNotEmpty) ...[
                  const Divider(height: 24),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widget.customActions!,
                    ),
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