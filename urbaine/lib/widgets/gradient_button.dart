import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A modern button with gradient background and loading state
class GradientButton extends StatelessWidget {
  /// The child widget to display (typically a Text widget)
  final Widget child;
  
  /// Callback when button is pressed
  final VoidCallback? onPressed;
  
  /// Whether to show a loading indicator instead of the child
  final bool isLoading;
  
  /// Border radius of the button
  final BorderRadiusGeometry borderRadius;
  
  /// Height of the button
  final double height;
  
  /// Width of the button (null means full width)
  final double? width;
  
  /// Start color of the gradient
  final Color? startColor;
  
  /// End color of the gradient
  final Color? endColor;
  
  /// Gradient direction
  final Alignment beginGradient;
  
  /// Gradient end direction
  final Alignment endGradient;
  
  /// Shadow elevation
  final double elevation;

  /// Creates a gradient button
  const GradientButton({
    Key? key,
    required this.child,
    required this.onPressed,
    this.isLoading = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppTheme.borderRadiusLarge)),
    this.height = 50,
    this.width,
    this.startColor,
    this.endColor,
    this.beginGradient = Alignment.centerLeft,
    this.endGradient = Alignment.centerRight,
    this.elevation = 2,
    LinearGradient? gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = startColor ?? AppTheme.primaryColor;
    final secondary = endColor ?? AppTheme.secondaryColor;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: elevation > 0 
            ? [
                BoxShadow(
                  color: primary.withOpacity(0.3),
                  blurRadius: elevation * 3,
                  offset: Offset(0, elevation),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: secondary.withOpacity(0.2),
                  blurRadius: elevation * 5,
                  offset: Offset(0, elevation * 2),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withOpacity(0.7),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, secondary],
              begin: beginGradient,
              end: endGradient,
              stops: const [0.2, 1.0],
            ),
            borderRadius: borderRadius,
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: child,
                  ),
          ),
        ),
      ),
    );
  }
}
