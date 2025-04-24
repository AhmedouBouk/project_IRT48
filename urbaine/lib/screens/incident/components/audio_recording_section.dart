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
        child: isRecording
            ? _buildRecordingStatus(theme)
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.mic_rounded, size: 24),
                      label: const Text('Commencer l\'enregistrement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        elevation: 3,
                        shadowColor: AppTheme.accentRed.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: onStartRecording,
                    ),
                  ],
                ),
              ),
      );
    }
    
    // If we already have an audio path
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_none_rounded, color: AppTheme.accentTeal, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enregistrement audio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enregistrement audio sauvegardé',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 20),
                  label: Text(isPlaying ? 'Arrêter' : 'Écouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppTheme.accentTeal.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: isPlaying ? onStopPlaying : onPlayRecording,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_rounded, size: 20),
                  label: const Text('Supprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.errorColor,
                    elevation: 1,
                    shadowColor: Colors.grey.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppTheme.errorColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: onDeleteRecording,
                ),
              ),
            ],
          ),
          if (isRecording) _buildRecordingStatus(theme),
      ],
    ));
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
