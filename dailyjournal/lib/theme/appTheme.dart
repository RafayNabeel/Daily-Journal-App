import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,

  // Main colors
  scaffoldBackgroundColor: Colors.black,
  primaryColor: const Color(0xFF1A73E8), // blue
  canvasColor: Colors.black,

  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF1A73E8), // main blue
    onPrimary: Colors.white,
    secondary: Color(0xFF283446), // darker blue-gray (for secondary buttons / cards)
    onSecondary: Colors.white,
    background: Colors.black,
    onBackground: Colors.white,
    surface: Color(0xFF1A1A1A),
    onSurface: Colors.white,
  ),

  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
    bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
  ),

  
  
  
);
