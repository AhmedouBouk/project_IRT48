import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/incident_list_item.dart';
import '../../theme/app_theme.dart';
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement en cours...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
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
            color: AppTheme.primaryColor,
            backgroundColor: Colors.white,
            strokeWidth: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: syncedIncidents.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: IncidentListItem(
                    incident: syncedIncidents[index],
                    dateFormat: _dateFormat,
                    showSyncStatus: isOffline, // Only show sync status when offline
                  ),
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
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(Icons.history,
                  size: 80, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 24),
            Text('Aucun incident signalé',
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
            const SizedBox(height: 12),
            Text('Utilisez le bouton "+" pour signaler un incident',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser', 
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                elevation: 3,
                shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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