import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 앱 테마 정의
class AppTheme {
  // region 색상 정의
  static const Color _primaryLight = Color(0xFF245A68);
  static const Color _primaryDark = Color(0xFFA7D6DC);

  static const Color _backgroundLight = Color(0xFFF6F6F5);
  static const Color _backgroundDark = Color(0xFF292C30);

  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceDark = Color(0xFF383C41);

  static const Color _textPrimaryLight = Color(0xFF1C2024);
  static const Color _textPrimaryDark = Color(0xFFF5F6F7);

  static const Color _textSecondaryLight = Color(0xFF4F5A63);
  static const Color _textSecondaryDark = Color(0xFFCDD3D6);

  static const Color _dividerLight = Color(0xFFD9DDDF);
  static const Color _dividerDark = Color(0xFF555B60);
  static const Color _controlLight = Color(0xFFEBEEEF);
  static const Color _controlDark = Color(0xFF454A50);
  //endregion

  // endregion

  // region 텍스트 스타일
  static final TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 34,
      color: _textPrimaryLight,
    ),
    displayMedium: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 28,
      color: _textPrimaryLight,
    ),
    displaySmall: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 22,
      color: _textPrimaryLight,
    ),
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 17,
      letterSpacing: 0.15,
      color: _textPrimaryLight,
    ),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 20,
      color: _textPrimaryLight,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 16,
      letterSpacing: 0.15,
      color: _textPrimaryLight,
    ),
    titleSmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
      letterSpacing: 0.1,
      color: _textPrimaryLight,
    ),
    bodyLarge: TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 17,
      color: _textSecondaryLight,
    ),
    bodyMedium: TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 15,
      color: _textSecondaryLight,
    ),
    labelLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
      scaffoldBackgroundColor: _backgroundLight,

      colorScheme: const ColorScheme.light(
        primary: _primaryLight,
        secondary: _primaryLight,
        surface: _surfaceLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _textPrimaryLight,
        onSurfaceVariant: _textSecondaryLight,
        outline: _dividerLight,
        surfaceContainerHighest: _controlLight,
        error: Color(0xFFAE3542),
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
        fillColor: _controlLight,
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
      scaffoldBackgroundColor: _backgroundDark,

      colorScheme: const ColorScheme.dark(
        primary: _primaryDark,
        secondary: _primaryDark,
        surface: _surfaceDark,
        onPrimary: Color(0xFF0C2528),
        onSecondary: Color(0xFF0C2528),
        onSurface: _textPrimaryDark,
        onSurfaceVariant: _textSecondaryDark,
        outline: _dividerDark,
        surfaceContainerHighest: _controlDark,
        error: Color(0xFFF19BA2),
        onError: _backgroundDark,
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
        fillColor: _controlDark,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _dividerDark),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryDark,
          foregroundColor: const Color(0xFF0C2528),
          textStyle: _darkTextTheme.labelLarge,
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
