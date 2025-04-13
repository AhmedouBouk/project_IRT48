import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/incident_provider.dart';
import 'providers/connectivity_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize providers
  final authProvider = AuthProvider();
  final incidentProvider = IncidentProvider();
  final connectivityProvider = ConnectivityProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<IncidentProvider>.value(value: incidentProvider),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
      ],
      child: Builder(
        builder: (context) {
          // Connect providers to each other after initialization
          Future.microtask(() {
            // Set the auth provider inside incident provider
            incidentProvider.setAuthProvider(authProvider);

            // Set the auth provider inside connectivity provider
            connectivityProvider.setAuthProvider(authProvider);
          });

          return const UrbanIncidentApp(); // This is your main app widget (e.g., MaterialApp)
        },
      ),
    ),
  );
}
