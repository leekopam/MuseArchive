import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_album_app/utils/theme.dart';

void main() {
  test('A 팔레트와 회색 다크 테마가 화면 역할 색상에 적용된다', () {
    final light = AppTheme.light;
    final dark = AppTheme.dark;

    expect(light.scaffoldBackgroundColor, const Color(0xFFF6F6F5));
    expect(light.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(light.colorScheme.primary, const Color(0xFF245A68));
    expect(light.colorScheme.onSurface, const Color(0xFF1C2024));

    expect(dark.scaffoldBackgroundColor, const Color(0xFF292C30));
    expect(dark.colorScheme.surface, const Color(0xFF383C41));
    expect(dark.colorScheme.primary, const Color(0xFFA7D6DC));
    expect(dark.colorScheme.onSurface, const Color(0xFFF5F6F7));
    expect(dark.colorScheme.onSurfaceVariant, const Color(0xFFCDD3D6));
    expect(dark.textTheme.displayLarge?.fontSize, 34);
    expect(dark.textTheme.bodyMedium?.fontSize, 15);
    expect(dark.textTheme.bodyMedium?.fontFamily, isNot('System'));
  });

  test('다크 테마의 보조 글자와 강조색은 표면에서 4.5:1 이상이다', () {
    final scheme = AppTheme.dark.colorScheme;

    double contrast(Color foreground, Color background) {
      final values = [
        foreground.computeLuminance(),
        background.computeLuminance(),
      ]..sort();
      return (values.last + 0.05) / (values.first + 0.05);
    }

    expect(contrast(scheme.primary, scheme.surface), greaterThanOrEqualTo(4.5));
    expect(
      contrast(scheme.onSurfaceVariant, scheme.surface),
      greaterThanOrEqualTo(4.5),
    );
  });
}
