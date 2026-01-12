import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// region 테마 상태 관리
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
//endregion

// endregion

// region 테마 로드 및 저장
/// 저장된 테마 설정 로드
Future<void> loadTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
}

/// 테마 설정 저장
Future<void> saveTheme(bool isDark) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('is_dark_mode', isDark);
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
}
// endregion