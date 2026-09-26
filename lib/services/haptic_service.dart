import 'package:flutter/services.dart';

/// 시맨틱 액션별 햅틱 피드백 유틸리티
class HapticService {
  HapticService._();

  /// 경량 탭 (카드, 버튼, 아이콘 탭)
  static void lightTap() => HapticFeedback.lightImpact();

  /// 토글/확인 (스위치, 세그먼트, 뷰 모드 전환)
  static void toggle() => HapticFeedback.mediumImpact();

  /// 선택 (정렬 옵션, 검색 결과, 팝업 메뉴 항목)
  static void selection() => HapticFeedback.selectionClick();

  /// 성공 (저장 완료, 연결 테스트 성공)
  static void success() => HapticFeedback.mediumImpact();

  /// 경고/파괴적 액션 (삭제 확인)
  static void warning() => HapticFeedback.heavyImpact();

  /// 에러 (네트워크 에러, 유효성 검증 실패)
  static void error() => HapticFeedback.vibrate();

  /// 드래그 시작 (재정렬)
  static void dragStart() => HapticFeedback.mediumImpact();
}
