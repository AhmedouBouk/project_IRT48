import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/incident_list_item.dart';
class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final provider = Provider.of<IncidentProvider>(context, listen: false);
        if (provider.isLoading) {
          provider.forceCompleteLoading();
        }
      }
    });
  }

  @override
  void dispose() {
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
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement en cours...',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }

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
                return IncidentListItem(
                  incident: syncedIncidents[index],
                  dateFormat: _dateFormat,
                  showSyncStatus: isOffline, // Only show sync status when offline
                );
              },
            ),
          );
        },
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
              child: Icon(Icons.history,
                  size: 80, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text('Aucun incident signalé',
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Utilisez le bouton "+" pour signaler un incident',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7)),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
              style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimary,
                backgroundColor: theme.colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 2,
                shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Provider.of<IncidentProvider>(context, listen: false)
                    .loadIncidents();
              },
            )
          ],
        ),
      ),
    );
  }
}