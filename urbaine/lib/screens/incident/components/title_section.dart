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
      title: 'Titre',
      icon: Icons.title,
      child: TextFormField(
        controller: titleController,
        decoration: InputDecoration(
          hintText: 'Entrez un titre bref',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.short_text),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Veuillez entrer un titre';
          }
          return null;
        },
      ),
    );
  }
}
