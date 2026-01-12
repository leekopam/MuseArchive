/// 발매일 값 객체
class ReleaseDate {
  // region 필드
  final DateTime? date;
  //endregion

  // endregion

  // region 생성자
  const ReleaseDate(this.date);

  /// 문자열에서 날짜 파싱
  factory ReleaseDate.parse(String dateStr) {
    if (dateStr.isEmpty) return const ReleaseDate(null);
    try {
      final sanitized = dateStr.replaceAll(RegExp(r'[^0-9]'), '');
      if (sanitized.isEmpty) return const ReleaseDate(null);

      final year = int.parse(sanitized.substring(0, 4));
      final month = sanitized.length > 4
          ? int.parse(sanitized.substring(4, 6))
          : 1;
      final day = sanitized.length > 6
          ? int.parse(sanitized.substring(6, 8))
          : 1;

      if (month < 1 || month > 12 || day < 1 || day > 31) {
        return ReleaseDate(DateTime(year));
      }

      return ReleaseDate(DateTime(year, month, day));
    } catch (e) {
      return const ReleaseDate(null);
    }
  }
  //endregion

  // endregion

  // region 메서드
  String format() {
    if (date == null) return '';
    return '${date!.year}.${date!.month.toString().padLeft(2, '0')}.${date!.day.toString().padLeft(2, '0')}';
  }

  bool get isValid => date != null;
  //endregion

  // endregion

  // region 연산자 오버라이드
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReleaseDate && other.date == date;
  }

  @override
  int get hashCode => date.hashCode;
  //endregion
}
