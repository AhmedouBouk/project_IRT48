import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../../providers/incident_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import 'components/components.dart';

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
        // Utiliser le répertoire de documents au lieu du répertoire temporaire
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final path = '${directory.path}/$fileName';
        
        debugPrint('🎙️ Début d\'enregistrement audio dans: $path');
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
      debugPrint('🎙️ Erreur d\'enregistrement: $e');
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
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange,
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: AppTheme.spacingSmall),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    const Icon(Icons.error_outline, color: AppTheme.errorColor),
                    const SizedBox(width: AppTheme.spacingSmall),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),

            // Incident type
            IncidentTypeSection(
              selectedIncidentType: _selectedIncidentType,
              onIncidentTypeChanged: (value) {
                setState(() {
                  _selectedIncidentType = value!;
                });
              },
            ),
            const SizedBox(height: AppTheme.spacingSmall),

            // Title
            TitleSection(titleController: _titleController),
            const SizedBox(height: AppTheme.spacingSmall),

            // Description
            DescriptionSection(
              descriptionController: _descriptionController,
              descriptionType: _descriptionType,
              onDescriptionTypeChanged: (value) {
                setState(() {
                  _descriptionType = value!;
                });
              },
              audioPath: _audioPath,
              isRecording: _isRecording,
              isPlaying: _isPlaying,
              recordDuration: _recordDuration,
              onStartRecording: _startRecording,
              onStopRecording: _stopRecording,
              onPlayRecording: _playRecording,
              onStopPlaying: _stopPlaying,
              onDeleteRecording: () {
                setState(() {
                  _audioPath = null;
                });
              },
            ),
            const SizedBox(height: AppTheme.spacingSmall),

            // Photo
            PhotoCaptureSection(
              photoFile: _photoFile,
              onGetImage: _getImage,
              onRemovePhoto: () {
                setState(() {
                  _photoFile = null;
                });
              },
            ),
            const SizedBox(height: AppTheme.spacingSmall),

            // Location
            LocationSection(
              latitude: _latitude,
              longitude: _longitude,
              address: _address,
              onRefreshLocation: _getCurrentLocation,
              isLoading: _isLocationLoading,
            ),
            const SizedBox(height: AppTheme.spacingMedium),

            // Submit
            GradientButton(
              height: 56,
              elevation: 3,
              isLoading: _isSubmitting,
              onPressed: _submitForm,
              child: const Text(
                'Valider',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
