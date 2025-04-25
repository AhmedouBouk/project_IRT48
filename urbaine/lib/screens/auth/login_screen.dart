import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/home/home_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
    debugPrint('LOGIN SUCCESS? $success');

    if (success) {
      // Navigate to home screen on successful login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Nom d\'utilisateur ou mot de passe incorrect';
      });
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.authenticateWithBiometrics();

    if (success) {
      // Navigate to home screen on successful biometric login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentification biométrique échouée';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo and app name
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMedium),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.report_problem_rounded,
                        size: 60,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  Text(
                    'Bienvenue sur Urbaine',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  Text(
                    'Connexion',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                  
                  // Login form card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusExtraLarge)),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMedium, 
                          vertical: AppTheme.spacingLarge),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Username field
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Nom d\'utilisateur',
                                hintText: 'Entrez votre nom d\'utilisateur',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre nom d\'utilisateur';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppTheme.spacingMedium),
                            
                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                hintText: 'Entrez votre mot de passe',
                                prefixIcon: const Icon(Icons.lock),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre mot de passe';
                                }
                                return null;
                              },
                            ),
                            
                            // Forgot password link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // TODO: implement password recovery
                                },
                                child: const Text('Mot de passe oublié ?',
                                    style: TextStyle(fontWeight: FontWeight.w500)),
                              ),
                            ),
                            
                            // Error message
                            if (_errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
                                padding: const EdgeInsets.all(AppTheme.spacingSmall),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                                    const SizedBox(width: AppTheme.spacingSmall),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(color: AppTheme.errorColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // Login button
                            const SizedBox(height: AppTheme.spacingSmall),
                            GradientButton(
                              onPressed: _isLoading ? null : _login,
                              isLoading: _isLoading,
                              height: 56,
                              child: const Text(
                                'Se connecter',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            
                            // Biometric login button
                            if (authProvider.isBiometricEnabled)
                              Padding(
                                padding: const EdgeInsets.only(top: AppTheme.spacingMedium),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: AppTheme.accentColor,
                                  ),
                                  onPressed: _isLoading ? null : _loginWithBiometrics,
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text(
                                    'Connexion par biométrie',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            
                            // Register link
                            const SizedBox(height: AppTheme.spacingLarge),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 4,
                              children: [
                                const Text('Vous n\'avez pas de compte ?'),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'S\'inscrire',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
