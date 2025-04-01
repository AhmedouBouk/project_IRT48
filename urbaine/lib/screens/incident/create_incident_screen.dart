import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/incident.dart';
import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/location_service.dart';

class CreateIncidentScreen extends StatefulWidget {
  const CreateIncidentScreen({Key? key}) : super(key: key);

  @override
  State<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends State<CreateIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final LocationService _locationService = LocationService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _picker = ImagePicker();
  
  XFile? _photoFile;
  String _selectedIncidentType = 'fire';
  double _latitude = 0.0;
  double _longitude = 0.0;
  String? _address;
  bool _isVoiceDescription = false;
  bool _isListening = false;
  bool _isLocationLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isSpeechAvailable = false;

  @override
  void initState() {
    super.initState();
    // Initialisation simplifiée
    _initSpeechSimple();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Version simplifiée de l'initialisation de la reconnaissance vocale
  Future<void> _initSpeechSimple() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
          });
        },
      );
      
      setState(() {
        _isSpeechAvailable = available;
      });
    } catch (e) {
      // Ignorer l'erreur, la fonctionnalité sera simplement désactivée
      setState(() {
        _isSpeechAvailable = false;
      });
    }
  }

  // Obtenir la localisation actuelle
  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude ?? 0.0, 
        position.longitude ?? 0.0
      );
      
      setState(() {
        _latitude = position.latitude ?? 0.0;
        _longitude = position.longitude ?? 0.0;
        _address = address;
        _isLocationLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Impossible d\'obtenir votre position. Veuillez activer la localisation.';
        _isLocationLoading = false;
      });
    }
  }

  // Prendre ou sélectionner une photo
  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _photoFile = pickedFile;
        });
      }
    } catch (e) {
      // Gérer l'erreur de sélection d'image
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de sélectionner l\'image: $e')),
      );
    }
  }

  // Démarrer ou arrêter la reconnaissance vocale
  void _toggleListening() {
    if (!_isListening) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  Future<void> _startListening() async {
    if (_isSpeechAvailable) {
      try {
        setState(() {
          _isListening = true;
          _isVoiceDescription = true;
        });
        
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _descriptionController.text = result.recognizedWords;
            });
          },
        );
      } catch (e) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  // Soumettre le formulaire
  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_photoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez prendre ou sélectionner une photo'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
      final incidentProvider = Provider.of<IncidentProvider>(context, listen: false);
      
      final success = await incidentProvider.createIncident(
        incidentType: _selectedIncidentType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        photoFile: _photoFile!,
        latitude: _latitude,
        longitude: _longitude,
        address: _address,
        isVoiceDescription: _isVoiceDescription,
      );
      
      if (success) {
        Navigator.pop(context);
        
        // Message différent selon si nous sommes en ligne ou non
        final bool isOnline = connectivityProvider.isOnline;
        final String message = isOnline 
          ? 'Incident signalé avec succès'
          : 'Incident enregistré localement. Il sera synchronisé lorsque vous serez en ligne.';
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            action: !isOnline ? SnackBarAction(
              label: 'Fermer',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ) : null,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Erreur lors de la création de l\'incident';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Une erreur s\'est produite. Veuillez réessayer.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final bool isOffline = !connectivityProvider.isOnline;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signaler un incident'),
      ),
      body: Stack(
        children: [
          // Message hors ligne
          if (isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: const Color(0xFFFF9800), // Orange
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode hors ligne. L\'incident sera enregistré localement.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
          // Contenu principal
          _isLocationLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: EdgeInsets.only(top: isOffline ? 32.0 : 0),
                child: _buildForm(),
              ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Message d'erreur
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // Type d'incident
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Type d\'incident',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedIncidentType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'fire',
                          child: Text('Incendie'),
                        ),
                        DropdownMenuItem(
                          value: 'accident',
                          child: Text('Accident'),
                        ),
                        DropdownMenuItem(
                          value: 'flood',
                          child: Text('Inondation'),
                        ),
                        DropdownMenuItem(
                          value: 'infrastructure',
                          child: Text('Problème d\'infrastructure'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Autre'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedIncidentType = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Titre de l'incident
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Titre',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Entrez un titre bref',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                       if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un titre';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Description de l'incident
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening 
                                ? Colors.red 
                                : (_isSpeechAvailable ? null : Colors.grey.withOpacity(0.5)),
                          ),
                          onPressed: _isSpeechAvailable ? _toggleListening : null,
                          tooltip: _isSpeechAvailable 
                              ? 'Dictée vocale' 
                              : 'Reconnaissance vocale non disponible',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Décrivez l\'incident en détail',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer une description';
                        }
                        return null;
                      },
                    ),
                    if (_isListening)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Écoute en cours... Parlez maintenant',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Photo de l'incident
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_photoFile != null)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb 
                              ? Image.network(
                                  _photoFile!.path,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: double.infinity,
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image, size: 50, color: Colors.grey),
                                          SizedBox(height: 8),
                                          Text('Image preview not available',
                                            style: TextStyle(color: Colors.grey[700])),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : Image.file(
                                  File(_photoFile!.path),
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              shadows: [Shadow(blurRadius: 3.0, color: Colors.black)],
                            ),
                            onPressed: () {
                              setState(() {
                                _photoFile = null;
                              });
                            },
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Prendre une photo'),
                            onPressed: () => _getImage(ImageSource.camera),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galerie'),
                            onPressed: () => _getImage(ImageSource.gallery),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Localisation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Localisation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Latitude: $_latitude\nLongitude: $_longitude',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    if (_address != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Adresse: $_address',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualiser la position'),
                      onPressed: _getCurrentLocation,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Bouton de soumission
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        Provider.of<ConnectivityProvider>(context).isOnline
                            ? 'Signaler l\'incident'
                            : 'Enregistrer localement',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}