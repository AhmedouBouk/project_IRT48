import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/incident_provider.dart';
import '../incident/incident_details_screen.dart';

class IncidentMapScreen extends StatefulWidget {
  const IncidentMapScreen({Key? key}) : super(key: key);

  @override
  State<IncidentMapScreen> createState() => _IncidentMapScreenState();
}

class _IncidentMapScreenState extends State<IncidentMapScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  void _loadIncidents() {
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = Provider.of<IncidentProvider>(context);
    final incidents = incidentProvider.incidents;

    return Stack(
      children: [
        // Liste des incidents avec leur localisation
        incidents.isEmpty
            ? const Center(
                child: Text(
                  'Aucun incident à afficher',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : ListView.builder(
                itemCount: incidents.length,
                itemBuilder: (context, index) {
                  final incident = incidents[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: _getIncidentIcon(incident.incidentType),
                      title: Text(incident.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(incident.incidentType),
                          const SizedBox(height: 4),
                          Text(
                            'Localisation: ${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF757575), // Grey 600 color
                            ),
                          ),
                          if (incident.address != null && incident.address!.isNotEmpty)
                            Text(
                              'Adresse: ${incident.address}',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF757575), // Grey 600 color
                              ),
                            ),
                        ],
                      ),
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
        
        // Indicateur de chargement
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
        
        // Bouton de rafraîchissement
        Positioned(
          top: 16.0,
          right: 16.0,
          child: FloatingActionButton(
            heroTag: 'refreshIncidentsFAB',
            mini: true,
            onPressed: () {
              incidentProvider.loadIncidents();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Actualisation des incidents...'),
                ),
              );
            },
            child: const Icon(Icons.refresh),
            tooltip: 'Actualiser les incidents',
          ),
        ),
      ],
    );
  }

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