import 'package:flutter/material.dart';

/// Tema DARK PREMIUM com identidade ROXO
/// Paleta de cores centralizada para manter consistência visual
class AppTheme {
  // ===== CORES DE FUNDO =====
  static const Color backgroundPrimary = Color(0xFF0E0F12); // Preto grafite
  static const Color backgroundSecondary = Color(0xFF151820); // Cards, seções
  static const Color backgroundElevated = Color(0xFF1C2030); // Modais, listas
  static const Color backgroundGenreCard = Color(0xFF1A1F2E); // Cards de gênero (mais claro)
  
  // ===== COR DE IDENTIDADE (ROXO) =====
  static const Color primaryPurple = Color(0xFF7C4DFF); // Roxo principal
  static const Color primaryPurpleDark = Color(0xFF5A36C9); // Roxo escuro
  static const Color primaryPurpleLight = Color(0xFF9A7DFF); // Roxo suave (hover/foco)
  
  // ===== VERMELHO (USO RESTRITO) =====
  static const Color accentRed = Color(0xFFC62828); // Vermelho mais escuro para botão Assistir
  static const Color accentRedLight = Color(0xFFE53935); // Vermelho para progresso e erros
  
  // ===== TEXTO =====
  static const Color textPrimary = Color(0xFFFFFFFF); // Texto principal
  static const Color textSecondary = Color(0xFFB0B3C6); // Texto secundário
  static const Color textDisabled = Color(0xFF6F7385); // Texto desativado
  
  // ===== GRADIENTES =====
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [primaryPurple, primaryPurpleDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ===== SOMBRAS =====
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 12,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];
  
  static List<BoxShadow> cardShadowSubtle = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: -1,
    ),
  ];
  
  static List<BoxShadow> purpleGlow = [
    BoxShadow(
      color: primaryPurple.withOpacity(0.25),
      blurRadius: 10,
      spreadRadius: 1,
    ),
  ];
  
  static List<BoxShadow> purpleGlowSubtle = [
    BoxShadow(
      color: primaryPurple.withOpacity(0.15),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
  
  // ===== THEME DATA =====
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryPurple,
      scaffoldBackgroundColor: backgroundPrimary,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: primaryPurpleLight,
        surface: backgroundSecondary,
        error: accentRed,
      ),
      fontFamily: 'Poppins',
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryPurple,
        unselectedItemColor: textDisabled,
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: backgroundSecondary,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentRed,
          foregroundColor: textPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textDisabled),
      ),
    );
  }
}
