import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 웹 `src/shared/ui/progress.tsx` 대응.
///
/// 웹은 트랙을 `bg-blue-600/20`(Tailwind 기본 blue-600 = `#2563eb`, 알파 20%)로
/// 깔고, 그 위에 `bg-white` 바를 `translateX(-(100 - value)%)`로 밀어 넣는다.
/// **이 프로젝트 팔레트의 색이 아니다** — Tailwind 기본값이 그대로 산 자리라
/// 토큰으로 바꾸지 않고 그 값을 옮긴다(규율 #4와 같은 판단: 웹이 고르지 않은
/// 값을 임의로 토큰에 맞추면 웹과 달라진다).
class AppProgress extends StatelessWidget {
  const AppProgress({
    required this.value,
    this.height = defaultHeight,
    this.barColor,
    super.key,
  });

  /// 웹 progress 루트의 `h-[4px]`. 수강권 카드는 `h-[2px]`로 덮는다.
  static const double defaultHeight = 4;

  /// 웹 `bg-blue-600/20` — Tailwind 기본 blue-600(`#2563EB`)의 20%.
  static const Color trackColor = Color(0x332563EB);

  /// 0~100. 웹 `value` prop과 같은 범위다.
  final double value;

  final double height;

  /// 웹 `progressClassName`. 기본은 `bg-white`, 수강권 만료 시 `bg-gray-400`.
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // 웹 `rounded-full` — 높이가 2~4px이라 반지름이 그 절반이면 알약 모양이 된다.
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: trackColor,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            // 웹은 100% 너비 바를 `translateX`로 왼쪽으로 밀어 잘라낸다.
            // 결과는 "value%만큼 채운 바"와 같고, Flutter에서는 그 결과를
            // 직접 표현하는 편이 읽힌다. **0~100 밖의 값을 잠근다** —
            // 웹은 `translateX(-120%)`도 그냥 화면 밖으로 밀지만,
            // `widthFactor`에 1을 넘는 값이 들어가면 부모를 넘치는
            // 오버플로가 된다.
            widthFactor: (value / 100).clamp(0.0, 1.0),
            child: ColoredBox(color: barColor ?? Colors.white),
          ),
        ),
      ),
    );
  }

  /// 만료 수강권의 바 색(웹 `cn(... && 'bg-gray-400')`).
  static Color expiredBarColor(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!.gray400;
}
