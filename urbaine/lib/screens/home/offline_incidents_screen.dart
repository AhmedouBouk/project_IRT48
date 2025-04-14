import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/incident.dart';
import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/api_service.dart';

class OfflineIncidentsScreen extends StatefulWidget {
  const OfflineIncidentsScreen({Key? key}) : super(key: key);

  @override
  State<OfflineIncidentsScreen> createState() => _OfflineIncidentsScreenState();
}

class _OfflineIncidentsScreenState extends State<OfflineIncidentsScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  bool _isPlaying = false; // if you want TTS, define it or remove TTS logic

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final bool isOnline = connectivityProvider.isOnline;
    final theme = Theme.of(context);

    return Scaffold(
      body: Consumer<IncidentProvider>(
        builder: (context, incidentProvider, _) {
          if (incidentProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter for unsynced incidents
          final unsyncedIncidents = incidentProvider.incidents
              .where((incident) => !incident.isSynced)
              .toList();

          if (unsyncedIncidents.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              if (isOnline && unsyncedIncidents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Incidents en attente de synchronisation (${unsyncedIncidents.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Synchroniser'),
                        onPressed: incidentProvider.isSyncing
                            ? null
                            : () => _syncIncidents(incidentProvider),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: unsyncedIncidents.length,
                  itemBuilder: (context, index) {
                    final inc = unsyncedIncidents[index];
                    return _OfflineIncidentListItem(
                      incident: inc,
                      dateFormat: _dateFormat,
                      // if you want TTS for offline items too, pass a TTS method
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.cloud_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucun incident hors ligne',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Les incidents créés hors ligne apparaîtront ici',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _syncIncidents(IncidentProvider incidentProvider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synchronisation des incidents en cours...'),
        duration: Duration(seconds: 2),
      ),
    );

    await incidentProvider.syncIncidents();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          incidentProvider.error != null
              ? 'Erreur de synchronisation: ${incidentProvider.error}'
              : 'Synchronisation terminée avec succès',
        ),
        backgroundColor: incidentProvider.error != null ? Colors.red : Colors.green,
      ),
    );
  }
}

// Single item for unsynced incidents
class _OfflineIncidentListItem extends StatefulWidget {
  final Incident incident;
  final DateFormat dateFormat;

  const _OfflineIncidentListItem({
    Key? key,
    required this.incident,
    required this.dateFormat,
  }) : super(key: key);

  @override
  State<_OfflineIncidentListItem> createState() => _OfflineIncidentListItemState();
}

class _OfflineIncidentListItemState extends State<_OfflineIncidentListItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inc = widget.incident;
    final dateText = (inc.createdAt != null) ? widget.dateFormat.format(inc.createdAt!) : '';

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
          side: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              leading: _buildThumbnail(inc),
              title: Text(
                inc.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
                        onPressed: () => _openInMaps(inc.latitude, inc.longitude),
                      ),
                  ],
                ),
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
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
          Text(
            'Type: ${inc.incidentTypeLabel}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Description',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
            child: Text(
              inc.description,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Google Maps.')),
      );
    }
  }

  Widget _buildThumbnail(Incident inc) {
    const size = 70.0;
    final borderRadius = BorderRadius.circular(12);

    if (inc.photo == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: borderRadius),
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
            errorBuilder: (_, __, ___) => _brokenImage(size, borderRadius),
          ),
        ),
        inc.photo!,
        size,
        borderRadius,
      );
    }

    try {
      return _buildImageContainer(
        ClipRRect(
          borderRadius: borderRadius,
          child: Image.file(
            File(inc.photo!),
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) => _brokenImage(size, borderRadius),
          ),
        ),
        inc.photo!,
        size,
        borderRadius,
      );
    } catch (_) {
      return _brokenImage(size, borderRadius);
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

  Widget _brokenImage(double size, BorderRadius borderRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: borderRadius),
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  void _showFullImageDialog(String pathOrUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Image de l\'incident', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image, size: 80)),
                        )
                      : Image.file(
                          File(pathOrUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image, size: 80)),
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
