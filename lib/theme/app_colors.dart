import 'package:flutter/material.dart';

class AppColors {
  // Base Backgrounds
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFF8F9FA);
  
  // Containers (for Tonal Layering)
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // White cards
  static const Color surfaceContainerLow = Color(0xFFF1F4F5); // Inset areas
  static const Color surfaceContainer = Color(0xFFEBEEF0); // Backgrounds housing cards
  
  // Brand / Actions — Lake Blue palette
  static const Color primary = Color(0xFF2B95B8);
  static const Color primaryContainer = Color(0xFFBDE8F6);
  static const Color onPrimary = Color(0xFFE3F6FC);
  static const Color onPrimaryContainer = Color(0xFF1D6E8A);
  
  // Text & Icons
  static const Color onSurface = Color(0xFF2D3335);
  static const Color onSurfaceVariant = Color(0xFF5A6062);
  
  // Status (Emergency / Warning)
  static const Color error = Color(0xFFA73B21);
  static const Color errorContainer = Color(0xFFFD795A);
  static const Color onErrorContainer = Color(0xFF6E1400);

  // Borders (Ghost Border Rule: 15% opacity only, never pure border)
  static const Color outlineVariant = Color(0xFFADB3B5);

  // Gradients
  static const LinearGradient signatureGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );
}
