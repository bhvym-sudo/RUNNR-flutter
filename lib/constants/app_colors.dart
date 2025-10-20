import 'package:flutter/material.dart';

/// RUNNR App Color Palette
/// Based on the original RUNNR design
class AppColors {
  // Background colors
  static const Color night = Color(0xFF000000); // #000000 - Main background
  static const Color eerieBlack = Color(
    0xFF0A0A0D,
  ); // #0a0a0d - Secondary background
  static const Color darkerBg = Color(
    0xFF08080B,
  ); // #08080b - Darker background
  static const Color davysGray = Color(
    0xFF1E202E,
  ); // #1e202e - Card/container background
  static const Color cardBg = Color(0xFF1E202E); // #1e202e - Card background

  // Accent colors
  static const Color accentColor = Color(
    0xFF3D59A1,
  ); // #3d59a1 - Primary accent
  static const Color accentHover = Color(
    0xFF4A6BB5,
  ); // #4a6bb5 - Hover/active state

  // Like/Favorite color (Rose/Red)
  static const Color likeColor = Color(0xFFE63946); // Rose red for like button
  static const Color likeColorDark = Color(
    0xFFD62839,
  ); // Darker rose for active state

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB3B3B3); // Light gray
  static const Color textTertiary = Color(0xFF6B6B7B); // Muted gray

  // Gradient backgrounds
  static LinearGradient get darkGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [eerieBlack, night],
  );

  static LinearGradient get accentGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentColor, accentHover],
  );
}
