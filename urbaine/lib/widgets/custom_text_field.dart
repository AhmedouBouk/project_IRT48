import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A customized text field with enhanced styling and features
class CustomTextField extends StatelessWidget {
  /// Controller for the text field
  final TextEditingController controller;
  
  /// Label text to display
  final String label;
  
  /// Hint text to display when field is empty
  final String? hintText;
  
  /// Icon to display at the start of the field
  final IconData? icon;
  
  /// Whether to obscure text (for passwords)
  final bool obscureText;
  
  /// Widget to display at the end of the field
  final Widget? suffixIcon;
  
  /// Validation function
  final String? Function(String?)? validator;
  
  /// Action to perform when the next button is pressed
  final TextInputAction? textInputAction;
  
  /// Keyboard type to display
  final TextInputType? keyboardType;
  
  /// Maximum number of lines
  final int? maxLines;
  
  /// Minimum number of lines
  final int? minLines;
  
  /// Whether the field is enabled
  final bool enabled;
  
  /// Whether to auto-correct text
  final bool autocorrect;
  
  /// Input formatters for the field
  final List<TextInputFormatter>? inputFormatters;
  
  /// Focus node for the field
  final FocusNode? focusNode;
  
  /// Callback when the field is submitted
  final Function(String)? onFieldSubmitted;
  
  /// Callback when the field changes
  final Function(String)? onChanged;

  /// Creates a custom text field
  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hintText,
    this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.textInputAction,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.autocorrect = true,
    this.inputFormatters,
    this.focusNode,
    this.onFieldSubmitted,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      enabled: enabled,
      autocorrect: autocorrect,
      inputFormatters: inputFormatters,
      focusNode: focusNode,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      style: theme.textTheme.bodyLarge,
      cursorColor: theme.colorScheme.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon != null ? Icon(icon, color: theme.colorScheme.primary) : null,
        suffixIcon: suffixIcon,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: true,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}
