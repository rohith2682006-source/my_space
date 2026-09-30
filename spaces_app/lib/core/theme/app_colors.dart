import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4338CA);

  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color accentPurple = Color(0xFF8B5CF6); // Purple
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0B0F19); // Midnight
  static const Color darkSurface = Color(0xFF131B2E);
  static const Color darkCard = Color(0xFF1A233A);
  static const Color darkBorder = Color(0xFF263352);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

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
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
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
