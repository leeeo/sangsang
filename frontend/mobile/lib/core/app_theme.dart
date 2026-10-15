import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF285C50);
  static const canvas = Color(0xFFF6F5F0);
  static const ink = Color(0xFF243C34);
  static const muted = Color(0xFF5F7067);
  static const line = Color(0xFFDCE3DC);
  static const soft = Color(0xFFE8EEE7);
  static const sent = Color(0xFF526789);
  static const received = Color(0xFF28675A);
  static const danger = Color(0xFFB33F3D);

  static Color sentOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFB3C6E7)
          : sent;

  static Color receivedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFA4CBB3)
          : received;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFFA4CBB3) : AppColors.primary,
      onPrimary: dark ? const Color(0xFF17231F) : Colors.white,
      primaryContainer: dark ? const Color(0xFF334B40) : AppColors.soft,
      onPrimaryContainer: dark ? const Color(0xFFECF1EA) : AppColors.ink,
      surface: dark ? const Color(0xFF22332C) : Colors.white,
      onSurface: dark ? const Color(0xFFECF1EA) : AppColors.ink,
      onSurfaceVariant: dark ? const Color(0xFFB6C4BA) : AppColors.muted,
      outlineVariant: dark ? const Color(0xFF43554A) : AppColors.line,
      outline: dark ? const Color(0xFF85998A) : const Color(0xFF7B8B80),
      error: dark ? const Color(0xFFFFB4AB) : AppColors.danger,
    );
    final canvas = dark ? const Color(0xFF17231F) : AppColors.canvas;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.45),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 14, height: 1.4),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withAlpha(28),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide.none,
        selectedColor: scheme.primary.withAlpha(28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
