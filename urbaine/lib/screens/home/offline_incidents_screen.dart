import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../incident/incident_details_screen.dart';

class OfflineIncidentsScreen extends StatefulWidget {
  const OfflineIncidentsScreen({Key? key}) : super(key: key);

  @override
  State<OfflineIncidentsScreen> createState() => _OfflineIncidentsScreenState();
}

class _OfflineIncidentsScreenState extends State<OfflineIncidentsScreen> {
  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final bool isOnline = connectivityProvider.isOnline;
    
    return Consumer<IncidentProvider>(
      builder: (context, incidentProvider, _) {
        final unsyncedIncidents = incidentProvider.unsyncedIncidents;
        
        // If online and no unsynced incidents, show message
        if (isOnline && unsyncedIncidents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_done,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tous les incidents sont synchronisés',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aucun incident en attente de synchronisation',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }
        
        // If loading, show loading indicator
        if (incidentProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // If no unsynced incidents, show empty state
        if (unsyncedIncidents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aucun incident hors ligne',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Les incidents créés hors ligne apparaîtront ici',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }
        
        // Show list of unsynced incidents
        return Column(
          children: [
            // Header with sync button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Incidents en attente de synchronisation (${unsyncedIncidents.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (isOnline && unsyncedIncidents.isNotEmpty)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Synchroniser'),
                      onPressed: incidentProvider.isSyncing
                        ? null
                        : () => _syncIncidents(incidentProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                ],
              ),
            ),
            
            // List of unsynced incidents
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: unsyncedIncidents.length,
                itemBuilder: (context, index) {
                  final incident = unsyncedIncidents[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: _getIncidentIcon(incident.incidentType),
                      title: Text(incident.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(incident.incidentTypeLabel),
                          const SizedBox(height: 4),
                          Text(
                            'Créé le: ${_formatDate(incident.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.cloud_upload, color: Colors.orange),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IncidentDetailsScreen(incident: incident),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Format date
  String _formatDate(DateTime? date) {
    if (date == null) return 'Date inconnue';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  // Sync incidents with user feedback
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
            : 'Synchronisation terminée avec succès'
        ),
        backgroundColor: incidentProvider.error != null 
          ? Colors.red 
          : Colors.green,
      ),
    );
  }
  
  // Get icon for incident type
  Widget _getIncidentIcon(String incidentType) {
    IconData iconData;
    Color iconColor;

    switch (incidentType) {
      case 'fire':
        iconData = Icons.local_fire_department;
        iconColor = const Color(0xFFF44336); // Red color
        break;
      case 'accident':
        iconData = Icons.car_crash;
        iconColor = const Color(0xFFFF9800); // Orange color
        break;
      case 'flood':
        iconData = Icons.water;
        iconColor = const Color(0xFF2196F3); // Blue color
        break;
      case 'infrastructure':
        iconData = Icons.construction;
        iconColor = const Color(0xFFFFCA28); // Amber color
        break;
      default:
        iconData = Icons.warning;
        iconColor = const Color(0xFF9C27B0); // Purple color
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.2),
      child: Icon(
        iconData,
        color: iconColor,
      ),
    );
  }
}
