import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF8B5CF6); // Purple
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF6D28D9);

  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color accentPurple = Color(0xFF8B5CF6); // Purple
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF130B2A); // Matte purple
  static const Color darkSurface = Color(0xFF1B1233);
  static const Color darkCard = Color(0xFF24183F);
  static const Color darkBorder = Color(0xFF3B2A5B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // Light Theme Colors — Professional Cream White Palette
  static const Color lightBackground = Color(0xFFF6F4EE); // Elegant cream white background
  static const Color lightSurface = Color(0xFFFCFAF6); // Soft cream white surface
  static const Color lightCard = Color(0xFFFCFAF6); // Soft cream white card
  static const Color lightBorder = Color(0xFFE7E3D8); // Subtle cream stone border
  static const Color lightTextPrimary = Color(0xFF1C1917); // Deep warm stone (ultra readable)
  static const Color lightTextSecondary = Color(0xFF57534E); // Warm slate stone
  static const Color lightTextTertiary = Color(0xFF8C857B); // Soft muted cream-gray

  // Category Colors
  static const Color catDocument = Color(0xFF3B82F6); // Blue
  static const Color catImage = Color(0xFFEC4899); // Pink
  static const Color catVideo = Color(0xFF8B5CF6); // Purple
  static const Color catAudio = Color(0xFF10B981); // Green
  static const Color catArchive = Color(0xFFF59E0B); // Amber
  static const Color catCode = Color(0xFF06B6D4); // Cyan
  static const Color catNote = Color(0xFFEAB308); // Yellow
  static const Color catLink = Color(0xFF6366F1); // Indigo
  static const Color catOther = Color(0xFF64748B); // Slate

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
