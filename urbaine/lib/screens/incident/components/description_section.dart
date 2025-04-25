import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';
import 'audio_recording_section.dart';

/// A widget for entering incident description (text or audio)
class DescriptionSection extends StatefulWidget {
  /// Text controller for description input
  final TextEditingController descriptionController;
  
  /// Type of description ('text' or 'audio')
  final String descriptionType;
  
  /// Callback when description type changes
  final Function(String?) onDescriptionTypeChanged;
  
  /// Path to audio file if recorded
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

  /// Creates a description section widget
  const DescriptionSection({
    Key? key,
    required this.descriptionController,
    required this.descriptionType,
    required this.onDescriptionTypeChanged,
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
  State<DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<DescriptionSection> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }
  
  @override
  void didUpdateWidget(DescriptionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.descriptionType != widget.descriptionType) {
      _animationController.reset();
      _animationController.forward();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InfoCard(
      title: 'Description de l\'incident',
      icon: Icons.description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputTypeSwitcher(colorScheme),
          const SizedBox(height: AppTheme.spacingMedium),
          FadeTransition(
            opacity: _fadeAnimation,
            child: widget.descriptionType == 'text'
                ? _buildTextInput(colorScheme)
                : _buildAudioRecording(),
          ),
          if (widget.descriptionType == 'text')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '${widget.descriptionController.text.length}/1000 caractères',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.descriptionController.text.length > 900
                      ? Colors.red
                      : Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputTypeSwitcher(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              isSelected: widget.descriptionType == 'text',
              onTap: () => widget.onDescriptionTypeChanged('text'),
              icon: Icons.text_fields,
              label: 'Texte',
              colorScheme: colorScheme,
            ),
          ),
          Expanded(
            child: _TabButton(
              isSelected: widget.descriptionType == 'audio',
              onTap: () => widget.onDescriptionTypeChanged('audio'),
              icon: Icons.mic,
              label: 'Audio',
              colorScheme: colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.descriptionController,
          maxLines: 6,
          maxLength: 1000,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          decoration: InputDecoration(
            hintText: 'Décrivez l\'incident en détail',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, top: 12),
              child: Icon(Icons.edit_note, size: 22),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          style: const TextStyle(fontSize: 16),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez fournir une description';
            }
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          'Incluez les détails importants comme: l\'heure, le lieu, les personnes impliquées et les dommages éventuels.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAudioRecording() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AudioRecordingSection(
          audioPath: widget.audioPath,
          isRecording: widget.isRecording,
          isPlaying: widget.isPlaying,
          recordDuration: widget.recordDuration,
          onStartRecording: widget.onStartRecording,
          onStopRecording: widget.onStopRecording,
          onPlayRecording: widget.onPlayRecording, 
          onStopPlaying: widget.onStopPlaying,
          onDeleteRecording: widget.onDeleteRecording,
        ),
        if (!widget.isRecording && widget.audioPath == null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0, left: 4.0),
            child: Text(
              'Appuyez sur le bouton microphone pour commencer l\'enregistrement.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// A customized tab button widget for input type selection
class _TabButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _TabButton({
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      child: Semantics(
        label: 'Option $label',
        selected: isSelected,
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            border: isSelected 
                ? Border.all(color: colorScheme.primary.withOpacity(0.5), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? colorScheme.primary : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}