import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/ui/app_button.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/public/ui/SignUpCompletePage.tsx` 대응.
///
/// 요청을 하나도 보내지 않는다. 가입 자체는 **이 화면에 오기 전**
/// `/sign-up`의 mutation이 끝냈고, 여기는 그 결과를 쿼리스트링
/// (`?type=&name=`)으로 받아 보여주기만 한다.
///
/// **헤더가 없다.** 가입을 막 끝낸 사용자를 되돌려 보낼 곳이 없어서 웹도
/// `Layout.Header`를 두지 않았다.
///
/// **파라미터 누락 처리가 여기 없는 이유:** 웹은 화면 안에서
/// `if (!type || !name) throw new Error()`로 인자 없는 에러를 던져
/// `app/error.tsx`에 떨어진다. 앱에서 크래시는 부적절하므로 그 판단을
/// 라우터로 올렸다 — `/sign-in`이 `?type=`을 필수로 요구하는 게이트와
/// 같은 패턴이고, `app_test.dart`가 고정한다.
class SignUpCompletePage extends StatelessWidget {
  const SignUpCompletePage({
    required this.name,
    required this.memberType,
    required this.onConfirm,
    super.key,
  });

  /// 웹 `<Image width={100} height={100} />`.
  static const double imageSize = 100;

  /// 웹 확인 버튼의 `h-[57px]`. 로그인 화면의 44px가 아니다
  /// (`/select-gym` 하단 버튼과 같은 치수).
  static const double confirmButtonHeight = 57;

  /// 웹 `<span className='mb-[4px]'>`.
  ///
  /// 예외(토큰화하지 않는 리터럴): 4는 스케일의 1단(4)과 우연히 같지만 웹이
  /// 임의값 문법으로 적었다. 스케일 클래스가 아니므로 상수로 옮긴다(규율 #4).
  static const double badgeGap = 4;

  final String name;

  /// 'student' | 'trainer'. 확인 버튼이 로그인 화면으로 들고 가는 값이다.
  final String memberType;

  final ValueChanged<String> onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return AppLayout(
      // 웹 `<Layout className='bg-white'>`.
      backgroundColor: Colors.white,
      // 웹은 확인 버튼을 `Layout.BottomArea`가 아니라 **Contents 안에** 두고
      // `h-full` + `justify-between`으로 아래에 붙인다. `AppLayout`의 contents가
      // 이미 최소 뷰포트 높이를 보장하므로(그 `ConstrainedBox`가 있는 이유)
      // `spaceBetween`으로 그대로 재현된다 — 하단 슬롯으로 옮기면 구조가
      // 달라져 스크롤·키보드 동작이 웹과 어긋난다.
      contents: Padding(
        // 웹 바깥 div의 `p-7` = 사방 20.
        padding: EdgeInsets.all(spacing.s7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 웹 안쪽 div는 `h-full ... justify-center`로 남는 공간을 전부
            // 차지하고 그 안에서 가운데 정렬한다. **여기서 `Expanded`를 쓸 수
            // 없다** — `AppLayout`이 본문을 `SingleChildScrollView`로 감싸
            // 세로 제약이 unbounded이고, flex 자식은 무한 공간을 채울 수 없어
            // `RenderFlex children have non-zero flex but incoming height
            // constraints are unbounded`로 터진다.
            //
            // 대신 높이 0짜리 자식을 맨 위에 두고 `spaceBetween`에 맡긴다.
            // 자식이 셋이면 남는 공간이 **두 등분**되어 가운데 블록 위아래로
            // 같은 간격이 들어가므로, 결과 위치가 웹의 "버튼 위 영역에서 가운데"
            // 와 정확히 같아진다.
            const SizedBox.shrink(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/sign_up_complete.png',
                  width: imageSize,
                  height: imageSize,
                ),
                // 웹 `className='mb-7'` = 20.
                SizedBox(height: spacing.s7),
                Text(
                  '가입완료',
                  // 웹 `cn(Typography.HEADING_4_BOLD, 'mb-[4px] text-primary-500')`
                  // — 18px/130% bold. `HEADING_4`와 값이 같다.
                  style: AppTypography.heading4.copyWith(
                    color: colors.primary500,
                  ),
                ),
                const SizedBox(height: badgeGap),
                Text(
                  // 웹 `` {`${name}님, 환영합니다!`} ``.
                  '$name님, 환영합니다!',
                  // 웹 `cn(Typography.HEADING_1, 'text-gray-800')`.
                  style: AppTypography.heading1.copyWith(color: colors.gray800),
                ),
              ],
            ),
            AppButton(
              label: '확인',
              // 웹 `cn(Typography.TITLE_1_BOLD, 'h-[57px] w-full rounded-lg')`.
              height: confirmButtonHeight,
              labelStyle: AppTypography.title1,
              // 웹은 `Button asChild` + `<Link>` 조합이다. Flutter에는 Radix
              // Slot 개념이 없으므로 "이동하는 버튼"은 콜백으로 단순화된다.
              onPressed: () => onConfirm(memberType),
            ),
          ],
        ),
      ),
    );
  }
}
