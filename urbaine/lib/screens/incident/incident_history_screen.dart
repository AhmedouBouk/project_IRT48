import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/api_service.dart';
import '../../models/incident.dart';

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _initTts();

    // Optional: force-complete loading after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final provider = Provider.of<IncidentProvider>(context, listen: false);
        if (provider.isLoading) {
          provider.forceCompleteLoading();
        }
      }
    });
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

  Future<void> _speak(String text) async {
    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
      });
      await _flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final bool isOffline = !connectivityProvider.isOnline;
    final theme = Theme.of(context);

    return Scaffold(
      body: Consumer<IncidentProvider>(
        builder: (context, incidentProvider, _) {
          if (incidentProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement en cours...',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }

          // FILTER for only "synced" incidents
          final syncedIncidents = incidentProvider.incidents
              .where((incident) => incident.isSynced)
              .toList();

          if (syncedIncidents.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () => incidentProvider.loadIncidents(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: syncedIncidents.length,
              itemBuilder: (context, index) {
                return _IncidentListItem(
                  incident: syncedIncidents[index],
                  dateFormat: _dateFormat,
                  onSpeak: _speak,
                  isTtsPlaying: _isPlaying,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create incident screen
          // e.g. Navigator.push(...)
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
        tooltip: 'Signaler un incident',
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 80,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun incident signalé',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Utilisez le bouton "+" pour signaler un incident',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
              style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimary,
                backgroundColor: theme.colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Provider.of<IncidentProvider>(context, listen: false)
                    .loadIncidents();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
//  A custom widget for each synced incident item
// ----------------------------------------------------------------------
class _IncidentListItem extends StatefulWidget {
  final Incident incident;
  final DateFormat dateFormat;
  final Function(String text) onSpeak;
  final bool isTtsPlaying;

  const _IncidentListItem({
    Key? key,
    required this.incident,
    required this.dateFormat,
    required this.onSpeak,
    required this.isTtsPlaying,
  }) : super(key: key);

  @override
  State<_IncidentListItem> createState() => _IncidentListItemState();
}

class _IncidentListItemState extends State<_IncidentListItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inc = widget.incident;
    final dateText =
        (inc.createdAt != null) ? widget.dateFormat.format(inc.createdAt!) : '';

    // Always "synced" => no special offline badge needed
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              leading: _buildThumbnail(inc),
              title: Text(
                inc.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Here is where we show the type icon + type label + date & location
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row with type icon & label
                  Row(
                    children: [
                      _buildTypeIcon(inc.incidentType),
                      const SizedBox(width: 6),
                      Text(
                        inc.incidentTypeLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Row with date/time & location
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          dateText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (inc.latitude != 0.0 && inc.longitude != 0.0)
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: Icon(
                            Icons.location_on,
                            color: theme.colorScheme.primary,
                          ),
                          tooltip: 'Ouvrir dans Google Maps',
                          onPressed: () =>
                              _openInMaps(inc.latitude, inc.longitude),
                        ),
                    ],
                  ),
                ],
              ),
              trailing: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.primary,
                  ),
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded) _buildExpandedDescription(inc),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedDescription(Incident inc) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // We removed the type info from here – now it’s always visible above.
          const SizedBox(height: 4),
          Text(
            'Description',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (inc.isVoiceDescription)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isTtsPlaying ? Icons.stop : Icons.volume_up,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      tooltip: widget.isTtsPlaying
                          ? 'Arrêter la lecture'
                          : 'Lire la description',
                      onPressed: () => widget.onSpeak(inc.description),
                    ),
                  ),
                Text(
                  inc.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A small icon to represent the incident type
  Widget _buildTypeIcon(String type) {
    IconData iconData;
    Color iconColor;
    switch (type) {
      case 'fire':
        iconData = Icons.local_fire_department;
        iconColor = Colors.red;
        break;
      case 'accident':
        iconData = Icons.car_crash;
        iconColor = Colors.orange;
        break;
      case 'flood':
        iconData = Icons.water;
        iconColor = Colors.blue;
        break;
      case 'infrastructure':
        iconData = Icons.construction;
        iconColor = Colors.amber;
        break;
      default:
        iconData = Icons.warning;
        iconColor = Colors.purple;
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, size: 16, color: iconColor),
    );
  }

  // Launch Google Maps
  Future<void> _openInMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Impossible d\'ouvrir Google Maps.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // Build the thumbnail with photo
  Widget _buildThumbnail(Incident inc) {
    const size = 70.0;
    final borderRadius = BorderRadius.circular(12);

    if (inc.photo == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius,
        ),
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    if (inc.photo!.startsWith('http')) {
      return _buildImageContainer(
        ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(
            inc.photo!,
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) {
              return _buildBrokenImage(size, borderRadius);
            },
          ),
        ),
        inc.photo!,
        size,
        borderRadius,
      );
    }

    // local file
    try {
      return _buildImageContainer(
        ClipRRect(
          borderRadius: borderRadius,
          child: Image.file(
            File(inc.photo!),
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) {
              return _buildBrokenImage(size, borderRadius);
            },
          ),
        ),
        inc.photo!,
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
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.zoom_in, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrokenImage(double size, BorderRadius borderRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: const Icon(Icons.broken_image, color: Colors.grey),
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
