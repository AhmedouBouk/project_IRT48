import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/incident.dart';

/// A reusable widget for displaying an incident item in a list
/// Used by both OfflineIncidentsScreen and IncidentHistoryScreen
class IncidentListItem extends StatefulWidget {
  /// The incident to display
  final Incident incident;
  
  /// Date format to use for displaying the incident date
  final DateFormat dateFormat;
  
  /// Whether to show sync status badge
  final bool showSyncStatus;
  
  /// Optional custom action buttons to display in the expanded view
  final List<Widget>? customActions;

  const IncidentListItem({
    Key? key,
    required this.incident,
    required this.dateFormat,
    this.showSyncStatus = false,
    this.customActions,
  }) : super(key: key);

  @override
  State<IncidentListItem> createState() => _IncidentListItemState();
}

class _IncidentListItemState extends State<IncidentListItem> {
  bool _expanded = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Store subscriptions to cancel them in dispose
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // Set up audio player listeners
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    
    _durationSubscription = _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });
    
    _positionSubscription = _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _playAudio(String? audioPath) async {
    if (audioPath == null || audioPath.isEmpty) return;
    
    if (_isPlaying) {
      await _audioPlayer.stop();
    } else {
      try {
        // Check if the audio is a URL or local file
        if (audioPath.startsWith('http')) {
          await _audioPlayer.play(UrlSource(audioPath));
        } else {
          await _audioPlayer.play(DeviceFileSource(audioPath));
        }
      } catch (e) {
        debugPrint('Error playing audio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de lire l\'audio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = widget.dateFormat.format(widget.incident.createdAt ?? DateTime.now());
    final incident = widget.incident;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header with incident basic info
              ListTile(
                leading: _buildTypeIcon(incident.incidentType),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        incident.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.showSyncStatus)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: incident.isSynced
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                incident.isSynced
                                    ? Icons.cloud_done
                                    : Icons.cloud_off,
                                size: 12,
                                color: incident.isSynced
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                incident.isSynced ? 'Synchronisé' : 'Hors ligne',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: incident.isSynced
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (incident.photo != null)
                      _buildThumbnail(incident),
                    IconButton(
                      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      tooltip: _expanded ? 'Réduire' : 'Voir plus',
                    ),
                  ],
                ),
                onTap: () => setState(() => _expanded = !_expanded),
              ),
              
              // Expanded content with details
              if (_expanded)
                _buildExpandedDescription(incident),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDescription(Incident incident) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type
          Row(
            children: [
              Text(
                'Type:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getTypeColor(incident.incidentType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  incident.incidentTypeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getTypeColor(incident.incidentType),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Description
          Text(
            'Description:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Text(incident.description),
          ),
          
          const SizedBox(height: 16),
          
          // Location and audio player
          if (incident.latitude != 0.0 && incident.longitude != 0.0 || (incident.audioFile != null && incident.audioFile!.isNotEmpty))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (incident.latitude != 0.0 && incident.longitude != 0.0)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.location_on),
                    label: const Text('Voir sur la carte'),
                    onPressed: () => _openInMaps(incident.latitude, incident.longitude),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                
                // Audio player UI
                if (incident.audioFile != null && incident.audioFile!.isNotEmpty && _duration > Duration.zero)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enregistrement vocal:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _playAudio(incident.audioFile),
                              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                              color: theme.colorScheme.primary,
                            ),
                            Expanded(
                              child: Slider(
                                min: 0,
                                max: _duration.inSeconds.toDouble(),
                                value: _position.inSeconds.toDouble(),
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
                    ),
                  ),
                
                // Audio playback button if available
                if (incident.audioFile != null && incident.audioFile!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      onPressed: () => _playAudio(incident.audioFile),
                      icon: Icon(
                        _isPlaying ? Icons.stop : Icons.play_arrow,
                        color: theme.colorScheme.primary,
                      ),
                      tooltip: _isPlaying
                          ? 'Arrêter la lecture'
                          : 'Écouter l\'enregistrement',
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          
          // Custom actions if provided
          if (widget.customActions != null && widget.customActions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: widget.customActions!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    final color = _getTypeColor(type);
    final icon = _getTypeIcon(type);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'fire':
        return Icons.local_fire_department;
      case 'accident':
        return Icons.car_crash;
      case 'flood':
        return Icons.water;
      case 'infrastructure':
        return Icons.construction;
      default:
        return Icons.warning_amber;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'fire':
        return Colors.red;
      case 'accident':
        return Colors.orange;
      case 'flood':
        return Colors.blue;
      case 'infrastructure':
        return Colors.amber;
      default:
        return Colors.purple;
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Google Maps')),
      );
    }
  }

  Widget _buildThumbnail(Incident incident) {
    if (incident.photo == null || incident.photo!.isEmpty) {
      return const SizedBox.shrink();
    }

    final borderRadius = BorderRadius.circular(8);
    const size = 40.0;

    // Network image
    if (incident.photo!.startsWith('http')) {
      // First try to check network connectivity to avoid long timeouts
      if (!incident.isSynced) {
        // If incident isn't synced, we're likely offline, so show placeholder immediately
        return _buildImageContainer(
          _buildBrokenImage(size, borderRadius, true), // true indicates we're offline
          incident.photo!,
          size,
          borderRadius,
        );
      }
      
      return _buildImageContainer(
        ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(
            incident.photo!,
            fit: BoxFit.cover,
            width: size,
            height: size,
            // Faster timeout to avoid UI hanging
            cacheWidth: (size * 2).toInt(), // For better performance
            errorBuilder: (_, __, ___) {
              return _buildBrokenImage(size, borderRadius);
            },
          ),
        ),
        incident.photo!,
        size,
        borderRadius,
      );
    }

    // Local file
    try {
      return _buildImageContainer(
        ClipRRect(
          borderRadius: borderRadius,
          child: Image.file(
            File(incident.photo!),
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) {
              return _buildBrokenImage(size, borderRadius);
            },
          ),
        ),
        incident.photo!,
        size,
        borderRadius,
      );
    } catch (_) {
      return _buildBrokenImage(size, borderRadius);
    }
  }

  Widget _buildImageContainer(
    Widget child,
    String pathOrUrl,
    double size,
    BorderRadius borderRadius,
  ) {
    return GestureDetector(
      onTap: () => _showFullImageDialog(pathOrUrl),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            child,
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrokenImage(double size, BorderRadius borderRadius, [bool isOffline = false]) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Icon(
        isOffline ? Icons.cloud_off : Icons.broken_image, 
        color: isOffline ? Colors.orange[700] : Colors.grey, 
        size: 20
      ),
    );
  }

  void _showFullImageDialog(String pathOrUrl) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Image de l\'incident',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: pathOrUrl.startsWith('http')
                      ? Image.network(
                          pathOrUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, size: 80),
                          ),
                        )
                      : Image.file(
                          File(pathOrUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, size: 80),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
