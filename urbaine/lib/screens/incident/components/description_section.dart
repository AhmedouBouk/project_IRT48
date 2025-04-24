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
      icon: Icons.description_rounded,
      iconColor: AppTheme.primaryColor,
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
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: widget.descriptionController.text.length > 900
                        ? AppTheme.errorColor
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.descriptionController.text.length}/1000 caractères',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.descriptionController.text.length > 900
                          ? AppTheme.errorColor
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputTypeSwitcher(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              isSelected: widget.descriptionType == 'text',
              onTap: () => widget.onDescriptionTypeChanged('text'),
              icon: Icons.text_format_rounded,
              label: 'Texte',
              colorScheme: colorScheme,
            ),
          ),
          Expanded(
            child: _TabButton(
              isSelected: widget.descriptionType == 'audio',
              onTap: () => widget.onDescriptionTypeChanged('audio'),
              icon: Icons.mic_rounded,
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
            hintText: 'Décrivez l\'incident en détail...',
            hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            filled: true,
            fillColor: AppTheme.surfaceColor,
            contentPadding: const EdgeInsets.all(20),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: Icon(
                Icons.edit_note_rounded,
                size: 24,
                color: AppTheme.primaryColor.withOpacity(0.7),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
          ),
          style: const TextStyle(fontSize: 16, height: 1.5),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez fournir une description d\'incident';
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
          Container(
            margin: const EdgeInsets.only(top: 16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Appuyez sur le bouton microphone pour commencer l\'enregistrement audio.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
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
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      child: Semantics(
        label: 'Option $label',
        selected: isSelected,
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.primaryColor.withOpacity(0.1) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            border: isSelected 
                ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppTheme.primaryColor.withOpacity(0.15) 
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}