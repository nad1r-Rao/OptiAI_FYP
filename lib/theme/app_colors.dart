import 'package:flutter/material.dart';

/// A class that defines the color palette for the application.
///
/// This class contains static constant [Color] properties that are used
/// throughout the app to ensure a consistent and centralized color scheme,
/// particularly for the futuristic, neon-themed UI.
class AppColors {
  /// The primary background color, a very dark grey, almost black.
  static const background = Color(0xFF0D0D0D); 
  /// A bright, vibrant cyan color, used for primary interactive elements and highlights.
  static const neonBlue = Color(0xFF00FFFF);   
  /// A vivid purple color, often used for secondary actions or accents.
  static const neonPurple = Color(0xFF9D00FF); 
  /// A glowing green color, used for accents, icons, and indicators.
  static const neonGreen = Color(0xFF39FF14);  
  /// An off-white color with a greyish tint, used for body text to reduce harsh contrast.
  static const softWhite = Color(0xFFE0E0E0);  
}
