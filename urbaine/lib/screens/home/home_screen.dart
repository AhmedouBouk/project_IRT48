import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/offline_banner.dart';
import '../incident/create_incident_screen.dart';
import '../incident/incident_history_screen.dart';
import 'incident_map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const IncidentMapScreen(),
    const IncidentHistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Charger les incidents au démarrage
    Future.microtask(() {
      Provider.of<IncidentProvider>(context, listen: false).loadIncidents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final incidentProvider = Provider.of<IncidentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Urban Incident Reporter'),
        actions: [
          // Bouton de synchronisation (visible uniquement hors ligne)
          if (!connectivityProvider.isOnline)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Synchroniser les données',
              onPressed: incidentProvider.isSyncing
                  ? null
                  : () {
                      incidentProvider.syncIncidents();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Synchronisation en cours...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
            ),
          // Bouton de déconnexion
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: const Text('Voulez-vous vraiment vous déconnecter ?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        authProvider.logout();
                      },
                      child: const Text('Déconnecter'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bannière hors ligne
          if (!connectivityProvider.isOnline)
            const OfflineBanner(),
          
          // Contenu principal
          Expanded(
            child: _pages[_currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Carte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'homeScreenFAB',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateIncidentScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Signaler un incident',
      ),
    );
  }
}