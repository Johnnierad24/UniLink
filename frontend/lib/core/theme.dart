import 'package:flutter/material.dart';

class UniLinkTheme {
  static const _primary = Color(0xFF001E40);
  static const _secondary = Color(0xFF006A6A);

  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        primary: _primary,
        secondary: _secondary,
        surface: const Color(0xFFF9F9FE),
      ),
      scaffoldBackgroundColor: const Color(0xFFF9F9FE),
      useMaterial3: true,
      fontFamily: 'Public Sans',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E2E7)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          color: _primary,
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        primary: _primary,
        secondary: _secondary,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      fontFamily: 'Public Sans',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      scaffoldBackgroundColor: const Color(0xFF16162A),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2D2D44)),
        ),
      ),
    );
  }
}
