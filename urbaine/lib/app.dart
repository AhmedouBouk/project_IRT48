import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/animated_splash_screen.dart';
import 'theme/app_theme.dart';

/// Main application widget that sets up the theme and routing
class UrbanIncidentApp extends StatelessWidget {
  const UrbanIncidentApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Incident Reporter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isInitializing) {
            return const AnimatedSplashScreen();
          }
          if (authProvider.isAuthenticated) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}