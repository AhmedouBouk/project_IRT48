import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/gradient_button.dart';
import '../incident/create_incident_screen.dart';
import '../incident/incident_history_screen.dart';
import 'offline_incidents_screen.dart';
import '../auth/login_screen.dart'; // Assure-toi que c’est le bon chemin pour LoginScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const IncidentHistoryScreen(),
    const OfflineIncidentsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final incidentProvider = Provider.of<IncidentProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      incidentProvider.setAuthProvider(authProvider);
      incidentProvider.loadIncidents();

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && incidentProvider.isLoading) {
          incidentProvider.forceCompleteLoading();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final theme = Theme.of(context);

    final bool isOffline = !connectivityProvider.isOnline || authProvider.isOfflineMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Urban Incident Reporter'),
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
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
                      onPressed: () async {
                        Navigator.pop(context);
                        await authProvider.logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
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
          if (isOffline)
            OfflineBanner(
              isAuthOffline: authProvider.isOfflineMode,
            ),
          Expanded(
            child: _pages[_currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
        }),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_off),
            label: 'Hors ligne',
          ),
        ],
      ),
      floatingActionButton: GradientButton(
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateIncidentScreen()),
          );
        },
        height: 56,
        width: 56,
        borderRadius: BorderRadius.circular(28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
