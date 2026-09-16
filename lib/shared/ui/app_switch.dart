import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 웹 `src/shared/ui/switch.tsx`(Radix `Switch`) 대응.
///
/// ## 치수 (2026-09-15 브라우저 실측)
///
/// | | 값 | 웹 클래스 |
/// |---|---|---|
/// | 트랙 | **48 × 28** | `w-[48px]` + `border-2` |
/// | 손잡이 | **24 × 24** | `h-8 w-8`(커스텀 스케일 8 = 24) |
/// | 이동 거리 | **20** | `translate-x-7` |
/// | 켜짐 | `#1990FF` | `bg-primary`(= `--primary-500`) |
/// | 꺼짐 | `#CBCFD3` | `bg-gray-300` |
///
/// **트랙 높이 28은 클래스에 없다.** `border-2`(투명) 2 + 손잡이 24 + 2로
/// 만들어지는 값이다 — 그래서 손잡이가 트랙 안쪽 2px 자리에서 시작하고,
/// 이동 거리도 `48 - 4 - 24 = 20`으로 떨어진다. 트랙에 세로 패딩을 주는
/// 방식으로 옮기면 그 관계가 끊어진다.
///
/// 웹은 `transition-colors`(트랙)와 `transition-transform`(손잡이)을 각각
/// 건다. 지속 시간을 지정하지 않아 Tailwind 기본 **150ms**다.
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, required this.onChanged, super.key});

  /// 웹 `w-[48px]`.
  static const double trackWidth = 48;

  /// 실측 높이. 위 클래스 주석 참고 — 보더 2 + 손잡이 24 + 2.
  static const double trackHeight = 28;

  /// 웹 `border-2`. 투명 보더라 **안쪽 여백처럼 보인다.**
  static const double trackBorder = 2;

  /// 웹 `h-8 w-8` = 24.
  static const double thumbSize = 24;

  /// 웹 `data-[state=checked]:translate-x-7` = 20.
  /// `trackWidth - trackBorder * 2 - thumbSize`와 같다.
  static const double thumbTravel = trackWidth - trackBorder * 2 - thumbSize;

  /// 웹 `transition-*`의 Tailwind 기본 지속 시간.
  static const Duration duration = Duration(milliseconds: 150);

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: duration,
        width: trackWidth,
        height: trackHeight,
        padding: const EdgeInsets.all(trackBorder),
        decoration: BoxDecoration(
          color: value ? colors.primary500 : colors.gray300,
          borderRadius: BorderRadius.circular(trackHeight / 2),
        ),
        child: AnimatedAlign(
          duration: duration,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumbSize,
            height: thumbSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
