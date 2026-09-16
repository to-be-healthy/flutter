import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../entity/diet/model/diet.dart';

/// 웹 `feature/log-diet/ui/TodayDiet.tsx`의 **타일 부분만**.
///
/// **Phase A 경계(사용자 결정, 2026-09-15):** 타일 3분기 렌더까지 옮긴다.
/// 탭하면 열리는 바텀시트와 그 안의 S3 presigned 업로드(`POST /api/v1/file` →
/// `PUT {presignedUrl}` → `POST /api/v1/diets/home`)는 Phase B다.
///
/// 웹에서는 타일 전체가 `SheetTrigger`라 누르면 시트가 열린다. 여기서
/// 아무 일도 하지 않게 두면 **죽은 UI**로 보이므로, 탭을 [onTapUnimplemented]
/// 로 올려서 화면이 "아직 안 된다"를 드러내게 한다.
class TodayDietTile extends StatelessWidget {
  const TodayDietTile({
    required this.meal,
    required this.onTapUnimplemented,
    super.key,
  });

  /// 웹 `h-[88px]`.
  static const double height = 88;

  /// 웹 `<IconCheck width={17} height={17} />`.
  static const double checkIconSize = 17;

  /// 웹 `<IconPlus width={20} height={20} />`.
  static const double plusIconSize = 20;

  /// 웹 썸네일 URL의 `?w=400&h=400&q=90`(CDN 리사이즈 파라미터).
  static const String thumbnailQuery = '?w=400&h=400&q=90';

  final DietMeal meal;
  final VoidCallback onTapUnimplemented;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final radius = theme.extension<AppRadius>()!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapUnimplemented,
      child: ClipRRect(
        // 웹 `rounded-md` = 8.
        borderRadius: BorderRadius.circular(radius.m),
        child: SizedBox(
          height: height,
          child: ColoredBox(
            color: colors.gray100,
            child: Center(child: _content(context, colors)),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppColors colors) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    switch (meal.tile) {
      case DietTile.fasting:
        // 웹: `IconCheck`(primary500) 위, `mb-1`(4) 아래 "단식".
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/check.svg',
              width: checkIconSize,
              height: checkIconSize,
              // 웹 `fill={'var(--primary-500)'}`. 자산이 `currentColor`라
              // 여기서 주입한다 — 빼면 검정 동그라미가 된다.
              theme: SvgTheme(currentColor: colors.primary500),
            ),
            SizedBox(height: spacing.s1),
            Text(
              '단식',
              style: AppTypography.title2.copyWith(color: colors.gray400),
            ),
          ],
        );

      case DietTile.photo:
        return Image.network(
          '${meal.fileUrl}$thumbnailQuery',
          // 웹 `.custom-image { width:100%; height:100%; object-fit:cover }`.
          fit: BoxFit.cover,
          width: double.infinity,
          height: height,
          // 네트워크 이미지가 실패하면 빈 타일로 떨어뜨린다. 웹은 깨진
          // 이미지 아이콘을 그리는데, 앱에서 예외가 올라오면 카드 전체가
          // 빨간 에러 박스가 된다.
          errorBuilder: (context, error, stackTrace) => _plus(colors),
        );

      case DietTile.empty:
        return _plus(colors);
    }
  }

  Widget _plus(AppColors colors) => SvgPicture.asset(
    'assets/images/plus.svg',
    width: plusIconSize,
    height: plusIconSize,
    // 웹 `fill={'var(--gray-500)'}`.
    theme: SvgTheme(currentColor: colors.gray500),
  );
}
