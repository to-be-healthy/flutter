import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../entity/gym/model/gym.dart';

/// 웹 `src/feature/mypage/ui/SelectGym.tsx` 대응.
///
/// **`AppButton`을 재사용하지 않는다.** 이유가 둘이다:
/// 1. 이 타일의 조합(80px · `gray100` 배경 · 검정 `HEADING_4` · 선택 시
///    `border-2 primary500` + 흰 배경)이 `AppButtonVariant` 넷 어디에도 없다.
/// 2. `AppButton.backgroundKeyFor(label)`은 **라벨로** 키를 만든다. 같은
///    이름의 헬스장이 목록에 둘 있으면 키가 충돌한다
///    (`docs/deferred-minors.md`가 남긴 한계). 여기서는 `gymId`로 키를 만든다.
class GymSelectList extends StatelessWidget {
  const GymSelectList({
    required this.gyms,
    required this.selectedGymId,
    required this.onSelected,
    super.key,
  });

  /// 웹 `<li className='mb-3 h-[80px] w-full'>`의 `h-[80px]`.
  ///
  /// 예외(토큰화하지 않는 리터럴): 80은 스페이싱 스케일에 없는 임의값이다.
  static const double tileHeight = 80;

  /// 웹 활성 타일의 `border-2`.
  static const double selectedBorderWidth = 2;

  final List<Gym> gyms;
  final int? selectedGymId;
  final ValueChanged<int> onSelected;

  /// 타일을 지목하는 키. `gymId`로 만든다 — 이름은 중복될 수 있다.
  static Key tileKey(int gymId) =>
      ValueKey<String>('GymSelectList.tile.$gymId');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: gyms
          .map((gym) {
            final isSelected = gym.gymId == selectedGymId;
            return Padding(
              // 웹 `<li className='mb-3 ...'>` = 8px. 마지막 항목에도 붙는다
              // (웹도 모든 li에 같은 클래스가 걸린다).
              padding: EdgeInsets.only(bottom: spacing.s3),
              child: GestureDetector(
                onTap: () => onSelected(gym.gymId),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  key: tileKey(gym.gymId),
                  height: tileHeight,
                  alignment: Alignment.center,
                  // 웹 Button `size='full'`의 `px-4` = 10px(커스텀 스케일).
                  padding: EdgeInsets.symmetric(horizontal: spacing.s4),
                  decoration: BoxDecoration(
                    // 웹: 선택 시 `bg-white`, 아니면 `bg-gray-100`.
                    color: isSelected ? Colors.white : colors.gray100,
                    // 웹 Button base의 `rounded-lg` = 12px.
                    borderRadius: BorderRadius.circular(radius.l),
                    border: isSelected
                        ? Border.all(
                            color: colors.primary500,
                            width: selectedBorderWidth,
                          )
                        : null,
                  ),
                  child: Text(
                    gym.name,
                    textAlign: TextAlign.center,
                    // 웹 `cn(Typography.HEADING_4, 'h-full text-black', ...)`.
                    //
                    // 예외(토큰화하지 않는 리터럴): `Colors.black`은 `AppColors`에
                    // 대응 토큰이 없는 프레임워크 상수다.
                    style: AppTypography.heading4.copyWith(color: Colors.black),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
