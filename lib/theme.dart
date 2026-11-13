import 'package:flutter/material.dart';

const ink = Color(0xFF17352B);
const green = Color(0xFF187451);
const lime = Color(0xFFD9F279);
const muted = Color(0xFF738079);
const canvas = Color(0xFFF5F7F8);
const line = Color(0xFFE5EBE8);
const coral = Color(0xFFBE5B42);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: green,
    primary: green,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: canvas,
  fontFamily: 'Segoe UI',
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: ink,
      letterSpacing: -1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: ink,
      letterSpacing: -.7,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: ink),
    bodyMedium: TextStyle(fontSize: 14, color: ink),
    bodySmall: TextStyle(fontSize: 12, color: muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: canvas,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFE8F3DD),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
    ),
  ),
  dividerTheme: const DividerThemeData(color: line, thickness: 1),
);

IconData categoryIcon(String category) => switch (category) {
  'Alimentação' => Icons.restaurant_rounded,
  'Moradia' => Icons.home_rounded,
  'Transporte' => Icons.directions_car_rounded,
  'Lazer' => Icons.sports_esports_rounded,
  'Saúde' => Icons.favorite_rounded,
  'Educação' => Icons.school_rounded,
  'Salário' => Icons.work_rounded,
  'Freelance' => Icons.laptop_mac_rounded,
  _ => Icons.grid_view_rounded,
};

Color categoryColor(String category) => switch (category) {
  'Alimentação' => const Color(0xFFB8833D),
  'Moradia' => green,
  'Transporte' => const Color(0xFF617DAD),
  'Lazer' => const Color(0xFF9A78AF),
  'Saúde' => coral,
  'Educação' => const Color(0xFF4C9C9C),
  _ => const Color(0xFF879566),
};
