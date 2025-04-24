import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';

/// A widget for selecting incident type
class IncidentTypeSection extends StatelessWidget {
  /// Currently selected incident type
  final String selectedIncidentType;
  
  /// Callback when incident type changes
  final Function(String?) onIncidentTypeChanged;

  /// Creates an incident type selection section
  const IncidentTypeSection({
    Key? key,
    required this.selectedIncidentType,
    required this.onIncidentTypeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Type d\'incident',
      icon: Icons.category_rounded,
      iconColor: AppTheme.primaryColor,
      child: DropdownButtonFormField<String>(
        value: selectedIncidentType,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppTheme.surfaceColor,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMedium,
            vertical: AppTheme.spacingMedium,
          ),
          prefixIcon: Icon(Icons.category_rounded, color: AppTheme.primaryColor.withOpacity(0.7)),
        ),
        icon: Icon(Icons.arrow_drop_down_circle, color: AppTheme.primaryColor),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        elevation: 3,
        isExpanded: true,
        items: [
          DropdownMenuItem(
            value: 'fire',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_fire_department, color: AppTheme.accentRed, size: 20),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                const Text('Incendie', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'accident',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.car_crash, color: AppTheme.secondaryColor, size: 20),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                const Text('Accident', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'flood',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.water_drop, color: AppTheme.accentTeal, size: 20),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                const Text('Inondation', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'infrastructure',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.handyman, color: AppTheme.accentAmber, size: 20),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                const Text('Problème d\'infrastructure', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'other',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.help_rounded, color: AppTheme.textSecondary, size: 20),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                const Text('Autre', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
        onChanged: onIncidentTypeChanged,
      ),
    );
  }
}
