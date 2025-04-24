import 'package:flutter/material.dart';

/// Centralized theme configuration for the Urban Incident Reporter app
class AppTheme {
  // Primary colors - warm purple and teal palette
  static const Color primaryColor = Color(0xFF7E57C2); // Deep purple
  static const Color secondaryColor = Color(0xFFFF6D00); // Deep orange
  static const Color accentColor = Color(0xFF26A69A); // Teal
  
  // Background colors
  static const Color scaffoldBackground = Color(0xFFF8F5FF); // Light purple tint
  static const Color cardBackground = Colors.white;
  static const Color surfaceColor = Color(0xFFFFFBF5); // Warm white
  
  // Text colors
  static const Color textPrimary = Color(0xFF2D2D3A); // Dark slate
  static const Color textSecondary = Color(0xFF5D5D6B); // Medium slate
  static const Color textLight = Color(0xFF8E8E99); // Light slate
  
  // Status colors
  static const Color errorColor = Color(0xFFD32F2F); // Red
  static const Color warningColor = Color(0xFFFF9800); // Orange
  static const Color successColor = Color(0xFF388E3C); // Green
  
  // Accent colors for variety
  static const Color accentPurple = Color(0xFFAB47BC); // Light purple
  static const Color accentAmber = Color(0xFFFFB300); // Amber
  static const Color accentTeal = Color(0xFF009688); // Teal
  static const Color accentRed = Color(0xFFE57373); // Light red
  
  // Elevation and shadows
  static const double cardElevation = 2.0;
  static const double buttonElevation = 1.0;
  
  // Border radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusExtraLarge = 24.0;
  
  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  
  // Get the theme data
  static ThemeData getTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        error: errorColor,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      
      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w300, fontSize: 32),
        displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w400, fontSize: 28),
        displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 24),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
        headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: TextStyle(color: textPrimary, height: 1.5, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, height: 1.5, fontSize: 14),
        bodySmall: TextStyle(color: textLight, height: 1.5, fontSize: 12),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(color: errorColor),
        ),
        prefixIconColor: primaryColor,
        suffixIconColor: textSecondary,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textLight),
        floatingLabelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
      ),
      
      // Card theme
      cardTheme: CardTheme(
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
          side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 0.5),
        ),
        color: cardBackground,
        margin: EdgeInsets.zero,
        shadowColor: primaryColor.withOpacity(0.1),
      ),
      
      // Button themes
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: buttonElevation,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusLarge),
          ),
          shadowColor: primaryColor.withOpacity(0.3),
        ),
      ),
      
      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
      
      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryColor,
        unselectedItemColor: textLight,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 22),
      ),
      
      // App bar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(borderRadiusMedium),
          ),
        ),
        shadowColor: primaryColor.withOpacity(0.2),
      ),
    );
  }
}
