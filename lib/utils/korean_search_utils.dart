/// 한글 초성(ㄱ~ㅎ) 검색 유틸리티.
/// 검색어가 초성으로만 이루어졌을 때 필드의 초성열과 부분 문자열 비교를 한다.
library;

/// 쿼리가 호환 자모가 아닌 초성 자모(ㄱ~ㅎ)로만 구성되었는지
bool isChoseongQuery(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return false;
  return trimmed.codeUnits.every((unit) => unit >= 0x3131 && unit <= 0x314E);
}

// 한글 음절 초성 인덱스(0~18) → 호환 자모 문자.
// 0x3131+인덱스로 선형 계산할 수 없다(종성 자모가 사이에 섞여 있음).
const String _initials = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';

/// 문자열을 초성열로 변환한다. 한글 음절은 초성으로, 그 외 문자는 그대로 둔다.
String toChoseong(String text) {
  final buffer = StringBuffer();
  for (final unit in text.codeUnits) {
    if (unit >= 0xAC00 && unit <= 0xD7A3) {
      // 음절 코드 = 0xAC00 + (초성 × 588) + (중성 × 28) + 종성
      buffer.write(_initials[(unit - 0xAC00) ~/ 588]);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// [choseongQuery]가 [target]의 초성열을 부분 문자열로 포함하는지.
/// 공백은 양쪽에서 무시한다 ("ㅂㅌㅅ"이 "방탄 소년단"에도 매치되도록).
bool matchesChoseong(String choseongQuery, String target) {
  final query = choseongQuery.replaceAll(RegExp(r'\s+'), '');
  final targetChoseong = toChoseong(target).replaceAll(RegExp(r'\s+'), '');
  return query.isNotEmpty && targetChoseong.contains(query);
}
