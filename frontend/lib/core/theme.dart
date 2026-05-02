import 'package:flutter/material.dart';

class UniLinkTheme {
  static const _primary = Color(0xFF001E40);
  static const _secondary = Color(0xFF006A6A);
  static const _darkPrimary = Color(0xFFA7C8FF);
  static const _darkSecondary = Color(0xFF76D6D5);
  static const _darkSurface = Color(0xFF16162A);
  static const _darkSurfaceContainer = Color(0xFF1F2037);

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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _darkPrimary,
      secondary: _darkSecondary,
      surface: _darkSurface,
      onSurface: Colors.white,
      primaryContainer: const Color(0xFF223252),
      onPrimaryContainer: Colors.white,
      secondaryContainer: const Color(0xFF173D3D),
      onSecondaryContainer: Colors.white,
      outline: const Color(0xFF4C5470),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Public Sans',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      scaffoldBackgroundColor: _darkSurface,
      cardTheme: CardThemeData(
        color: _darkSurfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2D2D44)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2D2D44)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.secondary, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.secondary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          side: BorderSide(color: colorScheme.secondary.withValues(alpha: 0.55)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceContainer,
        selectedColor: colorScheme.secondaryContainer,
        disabledColor: const Color(0xFF2A2D42),
        labelStyle: const TextStyle(color: Colors.white),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return colorScheme.onSurface;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.secondary;
            }
            return _darkSurfaceContainer;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outline.withValues(alpha: 0.6)),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        indicatorColor: colorScheme.secondary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? colorScheme.secondary
                : Colors.white70,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.secondary
                : Colors.white70,
          );
        }),
      ),
    );
  }
}
