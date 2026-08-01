import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../di/injection_container.dart';

class AppTheme {
  // --- THEME STATE MANAGER ---
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode
        .light, // Default to light mode; will be overridden by saved preference
  );

  static Future<void> loadThemePreference() async {
    try {
      // Call the storage engine directly from the service locator
      final storage = sl<FlutterSecureStorage>();
      final savedTheme = await storage.read(key: 'theme_mode');
      if (savedTheme == 'light') {
        themeNotifier.value = ThemeMode.light;
      } else {
        themeNotifier.value = ThemeMode.dark;
      }
    } catch (_) {
      // Default to dark mode on error
      themeNotifier.value = ThemeMode.dark;
    }
  }

  static void toggleTheme() {
    final newMode = themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    themeNotifier.value = newMode;
    try {
      // Call the storage engine directly from the service locator
      sl<FlutterSecureStorage>().write(
        key: 'theme_mode',
        value: newMode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {}
  }

  // --- Brand Colors ---
  static const Color primaryColor = Color(0xFF20C020);
  static const Color primaryLight = Color(0xFFEAF9EA);
  static const Color primaryDark = Color(0xFF158015);
  static const Color accentColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  // --- Backgrounds ---
  static const Color lightBackground = Color(0xFFF4F9F4);
  static const Color darkBackground = Color(0xFF0F172A);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: Colors.white,
        error: errorColor,
        onSurface: Color(0xFF1F2937),
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: const Color(0xFF1F2937),
        displayColor: const Color(0xFF111827),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 1,
        shadowColor: Color(0x1A000000),
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          color: primaryDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryColor.withOpacity(0.15), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          backgroundColor: primaryLight,
          side: const BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: primaryColor.withOpacity(0.1),
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: Color(0xFF1E293B),
        error: errorColor,
      ),
      textTheme: GoogleFonts.cairoTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
