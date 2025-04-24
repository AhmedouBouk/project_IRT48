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
                      child: Icon(Icons.cloud_off, size: 80, color: AppTheme.secondaryColor),
                    ),
                    const SizedBox(height: 24),
                    Text('Aucun incident hors ligne',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        )),
                    const SizedBox(height: 12),
                    Text('Les incidents créés sans connexion apparaîtront ici',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildSyncStatusIcon(incidentProvider, isOnline),
                          const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unsyncedIncidents.isEmpty
                                    ? 'Tous les incidents sont synchronisés'
                                    : 'Incidents non synchronisés (${unsyncedIncidents.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: incidentProvider.isSyncing 
                                      ? AppTheme.primaryColor 
                                      : unsyncedIncidents.isEmpty 
                                          ? AppTheme.successColor 
                                          : AppTheme.textPrimary,
                                ),
                              ),
                              if (!isOnline && unsyncedIncidents.isNotEmpty)
                                Text(
                                  'Mode hors ligne - Connectez-vous pour synchroniser',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                              if (incidentProvider.syncStatus == 'error')
                                Text(
                                  'Erreur de synchronisation - Nouvelle tentative en cours',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              if (incidentProvider.syncStatus == 'retrying')
                                Text(
                                  'Nouvelle tentative de synchronisation...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (unsyncedIncidents.isNotEmpty)
                          SizedBox(
                            height: 44,
                            width: 160, // Fixed width to prevent layout issues
                            child: GradientButton(
                              onPressed: (isOnline && !incidentProvider.isSyncing)
                                  ? () => _syncIncidents(incidentProvider)
                                  : null,
                              isLoading: incidentProvider.isSyncing,
                              width: 160, // Set explicit width on GradientButton
                              startColor: AppTheme.primaryColor,
                              endColor: AppTheme.secondaryColor,
                              elevation: 3,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.sync, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Synchroniser',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                    
                    // Progress indicator for syncing
                    if (incidentProvider.isSyncing)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                          ),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: incidentProvider.syncProgress,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.sync, size: 16, color: AppTheme.primaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Synchronisation en cours... ${(incidentProvider.syncProgress * 100).toInt()}%',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.primaryColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                      
                    // Success message
                    if (incidentProvider.syncStatus == 'success' && !incidentProvider.isSyncing)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.successColor.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                              const SizedBox(width: 12),
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