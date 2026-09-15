import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/public/ui/PolicyPage.tsx` 대응.
///
/// **자체 콘텐츠가 없는 순수 허브다.** 제목 한 줄과 링크 두 행뿐이고,
/// 약관 두 화면으로 들어가는 **유일한 경로**이기도 하다(웹 코드베이스 전체에서
/// `/policy/terms`·`/policy/privacy` 문자열이 이 화면 안에서만 등장한다).
///
/// 요청을 하나도 보내지 않는다 — 패리티 골든이 없는 이유이고, 하네스를
/// 빠뜨린 것이 아니라 대조할 요청 자체가 없다.
///
/// 이동을 콜백으로 받는 이유는 화면 테스트에 라우터를 끼우지 않기 위해서다
/// (`next-steps.md` §7-3). 실제 배선은 `app_router.dart`가 한다.
class PolicyPage extends StatelessWidget {
  const PolicyPage({required this.onBack, required this.onOpen, super.key});

  /// 웹 링크 행의 `py-[15px]`.
  ///
  /// 예외(토큰화하지 않는 리터럴): 15는 Tailwind 커스텀 스페이싱 스케일
  /// (4/6/8/10/12/16/20/24/28/32/36/48)에 없다 — 웹도 그래서 임의값 문법을 썼다.
  static const double rowVerticalPadding = 15;

  /// 웹 `arrow_right_small.svg`의 고유 크기(`width="7" height="10"`).
  static const double arrowWidth = 7;
  static const double arrowHeight = 10;

  final VoidCallback onBack;

  /// 누른 항목의 웹 경로를 넘긴다.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return AppLayout(
      // 웹 `<Layout className='bg-white'>`.
      backgroundColor: Colors.white,
      // 웹 헤더에는 뒤로가기 버튼 하나뿐이고 **제목이 없다**.
      header: AppLayoutHeader(onBack: onBack),
      contents: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // 웹 `px-7 pb-7 pt-8` — 좌우 20, 아래 20, 위 24.
            // `pt-8`은 커스텀 스케일에서 24이지 32가 아니다(규율 #5).
            padding: EdgeInsets.fromLTRB(
              spacing.s7,
              spacing.s8,
              spacing.s7,
              spacing.s7,
            ),
            child: const Text(
              '약관 및 정책',
              // 웹 `cn(Typography.HEADING_3, ...)` — 20px/130% bold.
              // 색 클래스가 없어 기본 foreground로 렌더된다.
              style: AppTypography.heading3,
            ),
          ),
          // 웹 `<section className='mt-7'>` = 20px.
          SizedBox(height: spacing.s7),
          _PolicyRow(
            label: '서비스 이용약관',
            onTap: () => onOpen(AppRoutes.policyTerms),
          ),
          _PolicyRow(
            label: '개인정보 처리방침',
            onTap: () => onOpen(AppRoutes.policyPrivacy),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // 웹 `px-7 py-[15px]`.
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s7,
          vertical: PolicyPage.rowVerticalPadding,
        ),
        child: Row(
          // 웹 `flex items-center justify-between`.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 웹 `cn(Typography.BODY_1)` — 16px/150% normal, 색 지정 없음.
            Text(label, style: AppTypography.body1),
            SvgPicture.asset(
              // 색을 덮지 않는다. 웹은 `stroke={'var(--gray-400)'}`를 넘기지만
              // **자산이 이미 `#A7A9AE`로 고정돼 있고 그 값이 곧 gray400이라
              // 실질적으로 no-op다**(실측: `global.css`의 `--gray-400: #a7a9ae`
              // = `AppColors.light.gray400`). `back.svg`·`close.svg`와 같은 처리다.
              'assets/images/arrow_right_small.svg',
              width: PolicyPage.arrowWidth,
              height: PolicyPage.arrowHeight,
            ),
          ],
        ),
      ),
    );
  }
}
