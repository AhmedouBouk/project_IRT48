import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/incident_card.dart';
import 'incident_details_screen.dart';

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load incidents with a timeout to prevent infinite loading
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final provider = Provider.of<IncidentProvider>(context, listen: false);
        if (provider.isLoading) {
          // Force loading to complete if it's taking too long
          provider.forceCompleteLoading();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final bool isOffline = !connectivityProvider.isOnline;
    
    return Consumer<IncidentProvider>(
      builder: (context, incidentProvider, _) {
        // Show loading indicator for a maximum of 3 seconds
        if (incidentProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Chargement en cours...'),
              ],
            ),
          );
        }
        
        final incidents = incidentProvider.incidents;
        final hasOfflineIncidents = incidentProvider.unsyncedIncidents.isNotEmpty;
        
        // If there are no incidents to display
        if (incidents.isEmpty) {
          return _buildEmptyState(incidentProvider);
        }
        
        return Column(
          children: [
            // Filter controls if there are offline incidents
            if (hasOfflineIncidents)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // First row with filter switch
                    Row(
                      children: [
                        const Text(
                          'Filtrer:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        // Switch to toggle offline-only filter
                        Switch(
                          value: incidentProvider.showOnlyOffline,
                          onChanged: (value) {
                            incidentProvider.showOnlyOffline = value;
                          },
                        ),
                        Expanded(
                          child: const Text(
                            'Incidents hors ligne uniquement',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Second row with sync button if offline
                    if (isOffline && hasOfflineIncidents)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.sync, size: 16),
                            label: const Text('Synchroniser'),
                            onPressed: incidentProvider.isSyncing 
                              ? null 
                              : () => _syncIncidents(incidentProvider),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            
            // List of incidents
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => incidentProvider.loadIncidents(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: incidents.length,
                  itemBuilder: (context, index) {
                    final incident = incidents[index];
                    return IncidentCard(
                      incident: incident,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IncidentDetailsScreen(
                              incident: incident,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Empty state widget to show when there are no incidents
  Widget _buildEmptyState(IncidentProvider incidentProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun incident signalé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Utilisez le bouton "+" pour signaler un incident',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Actualiser'),
            onPressed: () {
              incidentProvider.loadIncidents();
            },
          ),
        ],
      ),
    );
  }
  
  // Method to handle sync action with user feedback
  Future<void> _syncIncidents(IncidentProvider incidentProvider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synchronisation des incidents en cours...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    await incidentProvider.syncIncidents();
    
    // Show success message if connected
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          incidentProvider.error != null
            ? 'Erreur de synchronisation: ${incidentProvider.error}'
            : 'Synchronisation terminée avec succès'
        ),
        backgroundColor: incidentProvider.error != null 
          ? Colors.red 
          : Colors.green,
      ),
    );
  }
}