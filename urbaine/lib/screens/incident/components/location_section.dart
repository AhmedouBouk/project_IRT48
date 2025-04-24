import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';

/// A widget for displaying and refreshing location information
class LocationSection extends StatelessWidget {
  /// Latitude coordinate
  final double latitude;
  
  /// Longitude coordinate
  final double longitude;
  
  /// Address string derived from coordinates
  final String? address;
  
  /// Callback to refresh location
  final VoidCallback onRefreshLocation;
  
  /// Whether location is currently loading
  final bool isLoading;

  /// Creates a location section widget
  const LocationSection({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.onRefreshLocation,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Localisation',
      icon: Icons.location_on,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSmall),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Latitude: ${latitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: AppTheme.secondaryColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Longitude: ${longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (address != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSmall),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingSmall),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.home, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address!,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppTheme.spacingSmall),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: isLoading 
                  ? const SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(isLoading ? 'Actualisation...' : 'Actualiser la position'),
              onPressed: isLoading ? null : onRefreshLocation,
            ),
          ),
        ],
      ),
    );
  }
}
