import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable card widget with consistent styling for information sections
class InfoCard extends StatelessWidget {
  /// The title of the card (optional)
  final String? title;
  
  /// The child widget to display inside the card
  final Widget child;
  
  /// Additional padding to apply inside the card
  final EdgeInsetsGeometry padding;
  
  /// Whether to show a divider between the title and content
  final bool showDivider;
  
  /// Icon to display next to the title (optional)
  final IconData? icon;
  
  /// Action button to display in the title row (optional)
  final Widget? action;
  
  /// Background color of the card
  final Color? backgroundColor;
  
  /// Border radius of the card
  final BorderRadius? borderRadius;
  
  /// Elevation of the card
  final double elevation;

  /// Creates an info card
  const InfoCard({
    Key? key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingMedium),
    this.showDivider = false,
    this.icon,
    this.action,
    this.backgroundColor,
    this.borderRadius,
    this.elevation = AppTheme.cardElevation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardTheme.color ?? AppTheme.cardBackground,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: elevation > 0 
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Padding(
              padding: EdgeInsets.only(
                left: padding.horizontal / 2,
                right: padding.horizontal / 2,
                top: padding.vertical / 2,
                bottom: showDivider ? padding.vertical / 4 : padding.vertical / 2,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: AppTheme.spacingSmall),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
            if (showDivider)
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ],
          Padding(
            padding: EdgeInsets.only(
              left: padding.horizontal / 2,
              right: padding.horizontal / 2,
              top: title != null ? padding.vertical / 4 : padding.vertical / 2,
              bottom: padding.vertical / 2,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Extension to get horizontal and vertical values from EdgeInsetsGeometry
extension EdgeInsetsGeometryExtension on EdgeInsetsGeometry {
  double get horizontal {
    if (this is EdgeInsets) {
      final edgeInsets = this as EdgeInsets;
      return edgeInsets.left + edgeInsets.right;
    }
    return 32.0; // Default value
  }

  double get vertical {
    if (this is EdgeInsets) {
      final edgeInsets = this as EdgeInsets;
      return edgeInsets.top + edgeInsets.bottom;
    }
    return 32.0; // Default value
  }
}
