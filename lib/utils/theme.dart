import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 앱 테마 정의
class AppTheme {
  // region 색상 정의
  static const Color _primaryLight = Color(0xFF007AFF);
  static const Color _primaryDark = Color(0xFF0A84FF);

  static const Color _backgroundLight = Color(0xFFF2F2F7);
  static const Color _backgroundDark = Color(0xFF000000);

  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceDark = Color(0xFF1C1C1E);

  static const Color _textPrimaryLight = Color(0xFF000000);
  static const Color _textPrimaryDark = Color(0xFFFFFFFF);

  static const Color _textSecondaryLight = Color(0xFF3C3C43);
  static const Color _textSecondaryDark = Color(0xFFEBEBF5);

  static const Color _dividerLight = Color(0xFFDCDCDC);
  static const Color _dividerDark = Color(0xFF444446);
  //endregion

  // endregion

  // region 텍스트 스타
  static const _fontFamily = 'System';

  static final TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.bold,
      fontSize: 34,
      color: _textPrimaryLight,
    ),
    displayMedium: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.bold,
      fontSize: 28,
      color: _textPrimaryLight,
    ),
    displaySmall: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.bold,
      fontSize: 22,
      color: _textPrimaryLight,
    ),
    headlineMedium: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 17,
      letterSpacing: 0.15,
      color: _textPrimaryLight,
    ),
    titleLarge: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 20,
      color: _textPrimaryLight,
    ),
    titleMedium: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 16,
      letterSpacing: 0.15,
      color: _textPrimaryLight,
    ),
    titleSmall: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 14,
      letterSpacing: 0.1,
      color: _textPrimaryLight,
    ),
    bodyLarge: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.normal,
      fontSize: 17,
      color: _textSecondaryLight,
    ),
    bodyMedium: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.normal,
      fontSize: 15,
      color: _textSecondaryLight,
    ),
    labelLarge: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: Colors.white,
    ),
  ).apply(displayColor: _textPrimaryLight, bodyColor: _textSecondaryLight);

  static final TextTheme _darkTextTheme = _textTheme.apply(
    displayColor: _textPrimaryDark,
    bodyColor: _textSecondaryDark,
  );
  //endregion

  // endregion

  // region 라이트 테마
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: _primaryLight,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: _backgroundLight,

      colorScheme: const ColorScheme.light(
        primary: _primaryLight,
        secondary: _primaryLight,
        surface: _surfaceLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _textPrimaryLight,
        error: Colors.redAccent,
        onError: Colors.white,
      ),

      textTheme: _textTheme,

      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: _backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _primaryLight),
        titleTextStyle: _textTheme.headlineMedium!.copyWith(
          color: _textPrimaryLight,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dividerLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dividerLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryLight, width: 2),
        ),
        labelStyle: _textTheme.bodyMedium,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: _surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _dividerLight),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryLight,
          foregroundColor: Colors.white,
          textStyle: _textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }
  //endregion

  // endregion

  // region 다크 테마
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: _primaryDark,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: _backgroundDark,

      colorScheme: const ColorScheme.dark(
        primary: _primaryDark,
        secondary: _primaryDark,
        surface: _surfaceDark,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: _textPrimaryDark,
        error: Colors.redAccent,
        onError: Colors.white,
      ),

      textTheme: _darkTextTheme,

      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: _backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _primaryDark),
        titleTextStyle: _darkTextTheme.headlineMedium,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryDark, width: 2),
        ),
        labelStyle: _darkTextTheme.bodyMedium,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: _surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryDark,
          foregroundColor: _textPrimaryLight,
          textStyle: _textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  //endregion
}
