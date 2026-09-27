import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// region 감속 모션 지원

/// 플랫폼 접근성의 "애니메이션 삭제"(Android) 또는 "동작 줄이기"(iOS) 설정 여부.
bool get reduceMotionEnabled {
  final features =
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
  return features.disableAnimations || features.reduceMotion;
}

// endregion

// region 입장 애니메이션 제한 스코프

/// GridView.builder 등 지연 dispose 목록에서, 스크롤 복귀로 아이템이 재생성될 때
/// 입장 애니메이션이 다시 실행되는 깜빡임을 막는다.
/// 스코프 최초 마운트 후 [window]가 지난 뒤에 만들어지는 자식은 최종 상태로 바로 표시된다.
/// 시간 창은 State가 유지되는 동안 유지되므로 부모 재빌드로 리셋되지 않는다.
/// 다른 뷰로 전환해 새 목록에 애니메이션을 다시 주고 싶으면 키를 바꿔 State를 새로 만든다.
class EntryAnimationLimiter extends StatefulWidget {
  final Widget child;
  final Duration window;

  const EntryAnimationLimiter({
    super.key,
    required this.child,
    this.window = const Duration(milliseconds: 800),
  });

  @override
  State<EntryAnimationLimiter> createState() => _EntryAnimationLimiterState();
}

class _EntryAnimationLimiterState extends State<EntryAnimationLimiter> {
  // 벽시계 대신 프레임 타임스탬프를 쓴다. 테스트에서 pump()로 경과를 제어할 수 있고,
  // 실제 앱에서는 vsync에 맞춰 자연스럽게 증가한다.
  late final Duration _startTimestamp =
      SchedulerBinding.instance.currentFrameTimeStamp;

  @override
  Widget build(BuildContext context) {
    return _EntryAnimationScope(
      startTimestamp: _startTimestamp,
      window: widget.window,
      child: widget.child,
    );
  }
}

class _EntryAnimationScope extends InheritedWidget {
  final Duration startTimestamp;
  final Duration window;

  const _EntryAnimationScope({
    required this.startTimestamp,
    required this.window,
    required super.child,
  });

  bool get shouldAnimate =>
      SchedulerBinding.instance.currentFrameTimeStamp - startTimestamp < window;

  static _EntryAnimationScope? maybeOf(BuildContext context) {
    return context
            .getElementForInheritedWidgetOfExactType<_EntryAnimationScope>()
            ?.widget
        as _EntryAnimationScope?;
  }

  @override
  bool updateShouldNotify(_EntryAnimationScope oldWidget) => false;
}

// endregion

// region 탭 스케일 래퍼

/// 탭 시 스케일 축소 효과를 제공하는 래퍼 위젯
class TapScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final bool enabled;

  const TapScaleWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.965,
    this.enabled = true,
  });

  @override
  State<TapScaleWrapper> createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<TapScaleWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 140),
      vsync: this,
    );
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(curved);
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.55).animate(curved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.enabled && !reduceMotionEnabled) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}

// endregion

// region 페이드 슬라이드 진입 애니메이션

/// 페이드 + 슬라이드 진입 애니메이션 위젯 (스태거 지원)
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 20),
  });

  /// 그리드/리스트 아이템용 팩토리 (인덱스 기반 스태거, 최대 500ms)
  factory FadeSlideIn.staggered({
    Key? key,
    required Widget child,
    required int index,
    int intervalMs = 50,
    int maxDelayMs = 500,
  }) {
    return FadeSlideIn(
      key: key,
      delay: Duration(milliseconds: min(index * intervalMs, maxDelayMs)),
      child: child,
    );
  }

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    // SlideTransition은 위젯 크기 비율 기반이므로 소수값으로 변환
    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.beginOffset.dx / 100, widget.beginOffset.dy / 100),
      end: Offset.zero,
    ).animate(curved);

    // 감속 모션 설정이거나 스코프의 입장 시간 창이 지났으면 최종 상태로 바로 표시
    final scope = _EntryAnimationScope.maybeOf(context);
    if (reduceMotionEnabled || (scope != null && !scope.shouldAnimate)) {
      _controller.value = 1.0;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

// endregion

// region 커스텀 페이지 전환

/// 슬라이드 + 페이드 페이지 전환 라우트
class AnimatedPageRoute<T> extends PageRouteBuilder<T> {
  AnimatedPageRoute({required Widget page, super.settings})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (reduceMotionEnabled) return child;
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
}

// endregion
