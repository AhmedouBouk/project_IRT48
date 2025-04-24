import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';

/// A widget for entering incident title
class TitleSection extends StatelessWidget {
  /// Text controller for title input
  final TextEditingController titleController;

  /// Creates a title section widget
  const TitleSection({
    Key? key,
    required this.titleController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Titre de l\'incident',
      icon: Icons.title_rounded,
      iconColor: AppTheme.primaryColor,
      child: TextFormField(
        controller: titleController,
        style: TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Décrivez brièvement l\'incident',
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMedium,
            vertical: AppTheme.spacingMedium,
          ),
          prefixIcon: Icon(
            Icons.edit_note_rounded,
            color: AppTheme.primaryColor.withOpacity(0.7),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Veuillez entrer un titre pour l\'incident';
          }
          return null;
        },
      ),
    );
  }
}
