import 'package:flutter/material.dart';

/// A class that defines the typography styles for the application.
///
/// This class contains static constant [TextStyle] properties that are used for
/// headings and body text to ensure a consistent look and feel throughout the app.
class AppFonts {
  /// The [TextStyle] for headings.
  ///
  /// Uses the 'Orbitron' font family for a futuristic, digital look. It's bold
  /// and intended for titles and important text.
  static const heading = TextStyle(
    fontFamily: 'Orbitron', 
    fontSize: 24,
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  /// The [TextStyle] for body text.
  ///
  /// Uses the 'Roboto' font family, a clean and readable sans-serif font that is
  /// suitable for paragraphs and general content.
  static const body = TextStyle(
    fontFamily: 'Roboto',   
    fontSize: 16,
    color: Colors.white,
  );
}
