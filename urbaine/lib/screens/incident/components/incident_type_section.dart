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
      icon: Icons.warning_amber,
      child: DropdownButtonFormField<String>(
        value: selectedIncidentType,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMedium,
            vertical: AppTheme.spacingSmall,
          ),
        ),
        icon: const Icon(Icons.arrow_drop_down_circle_outlined),
        elevation: 2,
        isExpanded: true,
        items: const [
          DropdownMenuItem(
            value: 'fire',
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.red),
                SizedBox(width: AppTheme.spacingSmall),
                Text('Incendie'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'accident',
            child: Row(
              children: [
                Icon(Icons.car_crash, color: Colors.orange),
                SizedBox(width: AppTheme.spacingSmall),
                Text('Accident'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'flood',
            child: Row(
              children: [
                Icon(Icons.water, color: Colors.blue),
                SizedBox(width: AppTheme.spacingSmall),
                Text('Inondation'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'infrastructure',
            child: Row(
              children: [
                Icon(Icons.construction, color: Colors.amber),
                SizedBox(width: AppTheme.spacingSmall),
                Text('Problème d\'infrastructure'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'other',
            child: Row(
              children: [
                Icon(Icons.help_outline, color: Colors.grey),
                SizedBox(width: AppTheme.spacingSmall),
                Text('Autre'),
              ],
            ),
          ),
        ],
        onChanged: onIncidentTypeChanged,
      ),
    );
  }
}
