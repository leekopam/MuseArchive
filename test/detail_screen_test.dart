import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_album_app/screens/detail_screen.dart';
import 'package:my_album_app/utils/theme.dart';

void main() {
  test('Detail app bar uses readable foreground when expanded', () {
    final style = DetailAppBarStyle.fromTheme(
      AppTheme.light,
      isCollapsed: false,
    );

    expect(style.foregroundColor, Colors.white);
    expect(style.systemOverlayStyle.statusBarIconBrightness, Brightness.light);
  });

  test(
    'Detail app bar uses surface foreground when collapsed in light mode',
    () {
      final theme = AppTheme.light;
      final style = DetailAppBarStyle.fromTheme(theme, isCollapsed: true);

      expect(style.foregroundColor, theme.colorScheme.onSurface);
      expect(style.systemOverlayStyle.statusBarIconBrightness, Brightness.dark);
    },
  );

  test('Detail app bar keeps light system chrome in dark mode', () {
    final theme = AppTheme.dark;
    final style = DetailAppBarStyle.fromTheme(theme, isCollapsed: true);

    expect(style.foregroundColor, theme.colorScheme.onSurface);
    expect(style.systemOverlayStyle.statusBarIconBrightness, Brightness.light);
  });
}
