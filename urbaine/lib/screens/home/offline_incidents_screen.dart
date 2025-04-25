import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/incident_list_item.dart';
import '../../theme/app_theme.dart';

class OfflineIncidentsScreen extends StatefulWidget {
  const OfflineIncidentsScreen({Key? key}) : super(key: key);

  @override
  State<OfflineIncidentsScreen> createState() => _OfflineIncidentsScreenState();
}

class _OfflineIncidentsScreenState extends State<OfflineIncidentsScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final bool isOnline = connectivityProvider.isOnline;
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

          final unsyncedIncidents = incidentProvider.incidents
              .where((incident) => !incident.isSynced)
              .toList();

          if (unsyncedIncidents.isEmpty) {
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
                      child: Icon(Icons.cloud_off, size: 80, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text('Aucun incident hors ligne',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Les incidents créés sans connexion apparaîtront ici',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Header with sync status
                    Row(
                      children: [
                        _buildSyncStatusIcon(incidentProvider, isOnline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unsyncedIncidents.isEmpty
                                    ? 'Tous les incidents sont synchronisés'
                                    : 'Incidents non synchronisés (${unsyncedIncidents.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: incidentProvider.isSyncing 
                                      ? theme.colorScheme.primary 
                                      : unsyncedIncidents.isEmpty 
                                          ? Colors.green.shade700 
                                          : Colors.grey.shade800,
                                ),
                              ),
                              if (!isOnline && unsyncedIncidents.isNotEmpty)
                                Text(
                                  'Mode hors ligne - Connectez-vous pour synchroniser',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              if (incidentProvider.syncStatus == 'error')
                                Text(
                                  'Erreur de synchronisation - Nouvelle tentative en cours',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              if (incidentProvider.syncStatus == 'retrying')
                                Text(
                                  'Nouvelle tentative de synchronisation...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (unsyncedIncidents.isNotEmpty)
                          SizedBox(
                            height: 40,
                            width: 150, // Fixed width to prevent layout issues
                            child: GradientButton(
                              onPressed: (isOnline && !incidentProvider.isSyncing)
                                  ? () => _syncIncidents(incidentProvider)
                                  : null,
                              isLoading: incidentProvider.isSyncing,
                              width: 150, // Set explicit width on GradientButton
                              startColor: theme.colorScheme.primary,
                              endColor: theme.colorScheme.secondary,
                              child: Text(
                                'Synchroniser',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    // Progress indicator for syncing
                    if (incidentProvider.isSyncing)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: incidentProvider.syncProgress,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Synchronisation en cours... ${(incidentProvider.syncProgress * 100).toInt()}%',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                    // Success message
                    if (incidentProvider.syncStatus == 'success' && !incidentProvider.isSyncing)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Synchronisation réussie',
                                  style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: unsyncedIncidents.length,
                  itemBuilder: (context, index) {
                    final incident = unsyncedIncidents[index];
                    return IncidentListItem(
                      incident: incident,
                      dateFormat: _dateFormat,
                      showSyncStatus: true,
                      customActions: [
                        IconButton(
                          icon: const Icon(Icons.sync),
                          tooltip: 'Synchroniser cet incident',
                          onPressed: isOnline ? () {
                            // Individual sync functionality could be added here
                            _syncIncidents(incidentProvider);
                          } : null,
                        ),
                      ],
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

  Widget _buildSyncStatusIcon(IncidentProvider incidentProvider, bool isOnline) {
    if (incidentProvider.isSyncing) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }
    
    if (!isOnline) {
      return Icon(Icons.cloud_off, color: Colors.orange.shade700);
    }
    
    if (incidentProvider.syncStatus == 'error') {
      return Icon(Icons.error_outline, color: Colors.red.shade700);
    }
    
    if (incidentProvider.syncStatus == 'success') {
      return Icon(Icons.cloud_done, color: Colors.green.shade700);
    }
    
    if (incidentProvider.unsyncedIncidents.isEmpty) {
      return Icon(Icons.cloud_done, color: Colors.green.shade700);
    }
    
    return Icon(Icons.cloud_upload, color: Colors.grey.shade700);
  }

  Future<void> _syncIncidents(IncidentProvider provider) async {
    // Show sync message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synchronisation en cours...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Attempt synchronization
    final success = await provider.syncIncidents();

    // Show result feedback if the context is still valid
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Synchronisation terminée avec succès' 
                : 'Échec de la synchronisation. Réessayez ultérieurement.'
          ),
          backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}