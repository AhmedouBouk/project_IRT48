import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// A widget for handling audio recording functionality
class AudioRecordingSection extends StatelessWidget {
  /// Path to the audio file if already recorded
  final String? audioPath;
  
  /// Whether recording is in progress
  final bool isRecording;
  
  /// Whether audio is currently playing
  final bool isPlaying;
  
  /// Duration of the current recording
  final Duration recordDuration;
  
  /// Callback to start recording
  final VoidCallback onStartRecording;
  
  /// Callback to stop recording
  final VoidCallback onStopRecording;
  
  /// Callback to play the recording
  final VoidCallback onPlayRecording;
  
  /// Callback to stop playing
  final VoidCallback onStopPlaying;
  
  /// Callback to delete the recording
  final VoidCallback onDeleteRecording;

  /// Creates an audio recording section widget
  const AudioRecordingSection({
    Key? key,
    required this.audioPath,
    required this.isRecording,
    required this.isPlaying,
    required this.recordDuration,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onPlayRecording,
    required this.onStopPlaying,
    required this.onDeleteRecording,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (audioPath == null) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.mic),
          label: const Text('Commencer l\'enregistrement'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: isRecording ? null : onStartRecording,
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
                icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(isPlaying ? 'Arrêter' : 'Écouter'),
                onPressed: isPlaying ? onStopPlaying : onPlayRecording,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSmall),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Supprimer'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                onPressed: onDeleteRecording,
              ),
            ),
          ],
        ),
        if (isRecording) _buildRecordingStatus(theme),
        if (!isRecording)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacingSmall),
            child: Text(
              'Enregistrement audio sauvegardé',
              style: TextStyle(color: AppTheme.successColor, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildRecordingStatus(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: AppTheme.spacingMedium),
        const Text(
          'Enregistrement en cours...',
          style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Text(
          '${recordDuration.inMinutes.toString().padLeft(2, '0')}:${(recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 24),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        ElevatedButton.icon(
          icon: const Icon(Icons.stop),
          label: const Text('Arrêter l\'enregistrement'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
          onPressed: onStopRecording,
        ),
      ],
    );
  }
}
