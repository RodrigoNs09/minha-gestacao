import 'package:flutter/material.dart';

// Notifier global — controla o tema em todo o app
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class AppTheme {
  static const Color primaryPurple = Color(0xFF534AB7);
  static const Color lightPurple  = Color(0xFF7F77DD);
  static const Color pink          = Color(0xFFD4537E);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF0EEFF),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.light,
    ),
    fontFamily: 'Segoe UI',
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF13112A),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Segoe UI',
  );
}

/// Helper de cores adaptáveis — use em qualquer tela:
/// AppColors.surface(context), AppColors.textPrimary(context), etc.
class AppColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Backgrounds
  static Color scaffold(BuildContext context) =>
      isDark(context) ? const Color(0xFF13112A) : const Color(0xFFF0EEFF);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C1B2E) : Colors.white;

  static Color surfaceVariant(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A2740) : const Color(0xFFFDF6FF);

  // Texto
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFF0EBF8) : const Color(0xFF26215C);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFFAA9DC7) : const Color(0xFF888780);

  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF6B6485) : const Color(0xFFB4B2A9);

  // Accent
  static Color accent(BuildContext context) =>
      isDark(context) ? const Color(0xFFB9AADD) : const Color(0xFF534AB7);

  static Color accentText(BuildContext context) =>
      isDark(context) ? const Color(0xFFD4CAFF) : const Color(0xFF3C3489);

  // Stat cards
  static Color statPurple(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A2740) : const Color(0xFFEEEDFE);

  static Color statGreen(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A2E28) : const Color(0xFFE1F5EE);

  static Color statPink(BuildContext context) =>
      isDark(context) ? const Color(0xFF2E1A22) : const Color(0xFFFBEAF0);

  static Color statOrange(BuildContext context) =>
      isDark(context) ? const Color(0xFF2E2318) : const Color(0xFFFAEEDA);

  // Bordas
  static Color border(BuildContext context) =>
      isDark(context)
          ? const Color(0xFF2A2740)
          : const Color.fromRGBO(0, 0, 0, 0.07);

  static Color borderStrong(BuildContext context) =>
      isDark(context)
          ? const Color(0xFF3A3660)
          : const Color.fromRGBO(0, 0, 0, 0.08);

  // Nav bar
  static Color navBar(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C1B2E) : Colors.white;

  // Texto de label roxo
  static Color purpleLabel(BuildContext context) =>
      isDark(context) ? const Color(0xFF9B8ECC) : const Color(0xFF7F77DD);
}