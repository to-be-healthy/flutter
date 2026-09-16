import 'package:flutter/material.dart';

/// 웹 `src/shared/ui/collapsible.tsx`(Radix Collapsible 재export) 대응.
///
/// 웹에서 이 컴포넌트를 쓰는 홈 화면은 **열림 상태를 두 군데서 관리한다** —
/// Radix는 uncontrolled로 자기 상태를 갖고, 화면은 `isOpen` useState를 따로
/// 두어 `CollapsibleTrigger onClick`에서 둘을 함께 토글한다. 같은 클릭으로
/// 움직이니 버그는 아니지만 이중 상태다. Flutter에서는 **bool 하나로 합친다**
/// — 그래서 이 위젯은 controlled다(`isOpen`을 받는다).
class AppCollapsible extends StatelessWidget {
  const AppCollapsible({
    required this.isOpen,
    required this.trigger,
    required this.content,
    this.onToggle,
    super.key,
  });

  /// Radix `data-state=open/closed`의 애니메이션 길이
  /// (`tailwindcss-animate`의 accordion 기본값).
  static const Duration duration = Duration(milliseconds: 200);

  final bool isOpen;

  /// 항상 보이는 부분. 누르면 [onToggle].
  final Widget trigger;

  /// 열렸을 때만 보이는 부분.
  final Widget content;

  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `InkWell`이 아니라 `GestureDetector`다 — 웹 트리거에는 잉크 리플이
        // 없고, 이 트리거가 색 있는 카드 위에 얹혀 리플이 배경을 덮는다.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: trigger,
        ),
        // `AnimatedSize` + `SizedBox`로 높이를 0↔내용으로 접는다.
        // `Visibility`/`if`로 갈아치우면 Radix의 슬라이드가 사라진다.
        AnimatedSize(
          duration: duration,
          alignment: Alignment.topCenter,
          curve: Curves.easeOut,
          child: isOpen ? content : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
