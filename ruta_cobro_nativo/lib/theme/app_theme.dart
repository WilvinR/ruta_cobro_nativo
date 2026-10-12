import 'package:flutter/material.dart';

class AppTheme {
  static const black = Color(0xFF000000);
  static const surface = Color(0xFF111111);
  static const card = Color(0xFF1A1A1A);
  static const border = Color(0xFF2A2A2A);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFF999999);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const blue = Color(0xFF3B82F6);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: green,
          surface: surface,
          error: red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: black,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardTheme(
          color: card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white54),
          ),
          labelStyle: const TextStyle(color: muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: muted),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: black,
          selectedItemColor: Colors.white,
          unselectedItemColor: muted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerColor: border,
        useMaterial3: true,
      );
}
