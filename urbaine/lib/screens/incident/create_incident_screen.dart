import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

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
  final ImagePicker _picker = ImagePicker();
  final Record _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();

  XFile? _photoFile;
  String _selectedIncidentType = 'fire';
  double _latitude = 0.0;
  double _longitude = 0.0;
  String? _address;
  String _descriptionType = 'text'; // 'text' or 'audio'
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLocationLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _audioPath;
  Timer? _recordingTimer;
  Duration _recordDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stopRecording();
    _stopPlaying();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  // -----------------------------
  //       RECORDING LOGIC
  // -----------------------------
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(path: path);

        _recordDuration = Duration.zero;
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration = Duration(seconds: timer.tick);
          });
        });

        setState(() {
          _isRecording = true;
          _audioPath = path;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission d\'enregistrement refusée')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    await _audioRecorder.stop();

    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _playRecording() async {
    if (_audioPath == null) return;
    try {
      await _audioPlayer.play(DeviceFileSource(_audioPath!));
      setState(() {
        _isPlaying = true;
      });
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isPlaying = false;
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de lecture: $e')),
      );
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _stopPlaying() async {
    if (!_isPlaying) return;
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  // -----------------------------
  //       LOCATION LOGIC
  // -----------------------------
  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude ?? 0.0,
        position.longitude ?? 0.0,
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

  // -----------------------------
  //       IMAGE PICKER
  // -----------------------------
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de sélectionner l\'image: $e')),
      );
    }
  }

  // -----------------------------
  //       SUBMIT FORM
  // -----------------------------
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_descriptionType == 'text' && _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez fournir une description textuelle'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_descriptionType == 'audio' && _audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez enregistrer un message audio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_photoFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez prendre ou sélectionner une photo'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final incidentProvider = Provider.of<IncidentProvider>(context, listen: false);
      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);

      final description = (_descriptionType == 'text')
          ? _descriptionController.text.trim()
          : '[AUDIO_DESCRIPTION]'; // placeholder

      await incidentProvider.createIncident(
        incidentType: _selectedIncidentType,
        title: _titleController.text.trim(),
        description: description,
        photo: _photoFile,
        latitude: _latitude,
        longitude: _longitude,
        address: _address,
        isVoiceDescription: _descriptionType == 'audio',
        audioFile: _descriptionType == 'audio' ? _audioPath : null,
      );
      
      // Incident was created successfully
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connectivityProvider.isOnline
                ? 'Incident signalé avec succès!'
                : 'Incident enregistré localement. Il sera synchronisé lorsque vous serez en ligne.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // -----------------------------
  //           BUILD UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final isOffline = !connectivityProvider.isOnline;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signaler un incident'),
      ),
      body: Stack(
        children: [
          if (isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: Colors.orange,
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

          _isLocationLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: EdgeInsets.only(top: isOffline ? 32.0 : 0),
                  child: _buildForm(context),
                ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error message
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),

            // Incident type
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type d\'incident',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedIncidentType,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'fire', child: Text('Incendie')),
                      DropdownMenuItem(value: 'accident', child: Text('Accident')),
                      DropdownMenuItem(value: 'flood', child: Text('Inondation')),
                      DropdownMenuItem(value: 'infrastructure', child: Text('Problème d\'infrastructure')),
                      DropdownMenuItem(value: 'other', child: Text('Autre')),
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
            const SizedBox(height: 12),

            // Title
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Titre',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
            const SizedBox(height: 12),

            // Description
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description de l\'incident',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Texte'),
                          value: 'text',
                          groupValue: _descriptionType,
                          onChanged: (value) {
                            setState(() {
                              _descriptionType = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Audio'),
                          value: 'audio',
                          groupValue: _descriptionType,
                          onChanged: (value) {
                            setState(() {
                              _descriptionType = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_descriptionType == 'text')
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Décrivez l\'incident en détail',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez fournir une description';
                        }
                        return null;
                      },
                    )
                  else
                    _buildAudioRecordingSection(theme),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Photo
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photo',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                                  errorBuilder: (_, __, ___) {
                                    return Container(
                                      width: double.infinity,
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image, size: 50, color: Colors.grey),
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
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Photo'),
                            onPressed: () => _getImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('Galerie'),
                            onPressed: () => _getImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Location
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Localisation',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                        style: const TextStyle(fontStyle: FontStyle.italic),
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
            const SizedBox(height: 16),

            // Submit
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Valider'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioRecordingSection(ThemeData theme) {
    if (_audioPath == null) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.mic),
          label: const Text('Commencer l\'enregistrement'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _isRecording ? null : _startRecording,
        ),
      );
    }
    // If we already have an audio path
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlaying ? 'Arrêter' : 'Écouter'),
                onPressed: _isPlaying ? _stopPlaying : _playRecording,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Supprimer'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  setState(() {
                    _audioPath = null;
                  });
                },
              ),
            ),
          ],
        ),
        if (_isRecording) _buildRecordingStatus(theme),
        if (!_isRecording)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Enregistrement audio sauvegardé',
              style: TextStyle(color: Colors.green[700], fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildRecordingStatus(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Enregistrement en cours...',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${_recordDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 24),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.stop),
          label: const Text('Arrêter l\'enregistrement'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _stopRecording,
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
