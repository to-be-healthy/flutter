import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, ghost, outline }

/// 웹 `src/shared/ui/button` 대응.
///
/// 색·간격·라운드는 전부 ThemeExtension을 경유한다.
/// 화면 코드에서 리터럴 값을 쓰지 않기 위한 기준 구현이다.
///
/// 예외(토큰화하지 않는 리터럴): `Colors.white`·`Colors.transparent`는
/// `AppColors`에 대응 토큰이 없는 프레임워크 상수이고, 로딩 인디케이터의
/// `strokeWidth: 2`는 디자인 토큰이 아니라 Material 위젯 자체의 기본 굵기다.
/// `AppTypography`는 `ThemeExtension`이 아니라 정적 상수 모음이라 —
/// `AppTheme.light()`가 동일 상수로 `TextTheme`을 구성한다 — 여기서
/// `Theme.of(context).extension<...>()` 경유 대상이 아니다.
///
/// 비활성 배경은 웹 `button.tsx`의 base 클래스(`disabled:bg-gray-300`)를
/// 그대로 따라 variant와 무관하게 `gray300`이다. 웹에 `disabled:text-*`는
/// 없으므로 전경색은 비활성 여부와 상관없이 variant 기본값을 유지한다.
///
/// `outline`은 웹에서 제네릭하게 정의돼 있지만(`border border-input
/// bg-background`) 실제 호출부는 전부 색을 덮어쓴다 — 로그인 화면의
/// 회원가입 버튼이 `border-primary-500 text-primary-500`이다. 쓰이지 않는
/// `border-input`(CSS 변수)을 옮기는 대신 **실제로 쓰이는 형태**를 담는다.
/// 다른 색 조합이 필요해지면 그때 파라미터로 연다.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.height = defaultHeight,
    this.labelStyle,
    super.key,
  });

  /// 웹 `SignInForm.tsx:100`의 `h-[44px]` 대응. **기본값일 뿐 고정 치수가
  /// 아니다.**
  ///
  /// 예외(토큰화하지 않는 리터럴): 44는 `AppSpacing.standard`의 12단
  /// (4/6/8/10/12/16/20/24/28/32/36/48) 어디에도 없다 — 웹도 같은 이유로
  /// 스페이싱 클래스 대신 임의값 문법(`h-[44px]`)을 썼다.
  ///
  /// 웹 실측(2026-09-15): 버튼 높이는 화면마다 다르다 — `h-[48px]` 25회,
  /// `h-[57px]` 9회, `h-[44px]` 5회. 44는 로그인 화면이 고른 값이라 기본값에
  /// 두되, 화면이 [height]로 덮을 수 있어야 한다. 고정해 두면 62개 화면이
  /// 전부 로그인 화면의 높이를 물려받는다.
  ///
  /// 패딩 기반(`vertical: spacing.s6`)이던 이전 구현은 약 10px 높았다.
  static const double defaultHeight = 44;

  /// 배경을 그리는 [Container]에 붙는 키. 위젯 트리 모양이 아니라
  /// "배경이 어떤 색을 쓰는가"만 테스트가 검증할 수 있게 한다.
  ///
  /// `label`로 구분한다 — 화면 하나에 `AppButton`이 둘 이상(확인/취소 등)
  /// 있어도 각 인스턴스를 유일하게 찾을 수 있어야 하기 때문이다.
  static Key backgroundKeyFor(String label) =>
      ValueKey('AppButton.background.$label');

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;

  /// 칠해지는 상자의 높이. 웹의 `h-[Npx]`를 그대로 옮긴다.
  final double height;

  /// 라벨 타이포. 기본값은 웹 `TITLE_1_SEMIBOLD`.
  ///
  /// 웹 실측: `TITLE_1_BOLD` 77회 · `TITLE_1_SEMIBOLD` 84회로 둘 다 흔하다
  /// (`/select-gym`은 BOLD = `AppTypography.title1`).
  ///
  /// **색과 half-leading 보정은 이 컴포넌트가 계속 책임진다.** 넘긴 스타일의
  /// 색·`leadingDistribution`은 덮어써진다 — 그 둘까지 화면에 맡기면 62개
  /// 화면이 각자 다시 지정해야 하고, 하나라도 빠뜨리면 그 화면만 글자가
  /// 1~2px 어긋난다.
  ///
  /// 나머지(`fontSize` 포함)는 넘긴 스타일이 그대로 이긴다. 웹이 버튼
  /// 글자 크기를 바꾸는 화면이 있는지는 아직 실측하지 않았다 — 지금 쓰이는
  /// 것은 16px 두 종(`title1`/`title1SemiBold`)뿐이므로 굳이 막지 않는다.
  /// 다른 크기를 넘기는 화면이 생기면 그때 웹 렌더와 대조할 것.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    final isEnabled = onPressed != null && !isLoading;

    // 웹 button.tsx의 base가 `disabled:bg-gray-300` — variant 무관.
    final background = !isEnabled
        ? colors.gray300
        : switch (variant) {
            AppButtonVariant.primary => colors.primary500,
            AppButtonVariant.secondary => colors.blue50,
            AppButtonVariant.ghost => Colors.transparent,
            AppButtonVariant.outline => Colors.transparent,
          };

    // 웹은 비활성에서 전경색을 바꾸지 않는다(disabled:text-* 없음).
    final foreground = switch (variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.secondary => colors.primary500,
      AppButtonVariant.ghost => colors.gray600,
      AppButtonVariant.outline => colors.primary500,
    };

    // 웹 `outline`만 테두리를 가진다(`border border-input`, 호출부가
    // `border-primary-500`으로 덮어씀). 나머지 variant는 테두리가 없다.
    //
    // 비활성일 때 테두리를 지우는 이유: 배경이 `gray300`으로 바뀌는데
    // primary500 테두리가 남으면 웹에 없는 조합이 된다. 웹은
    // `disabled:bg-gray-300`이 `bg-background`를 덮고 테두리 색 클래스는
    // 그대로라 회색 배경 + 파란 테두리가 되지만, 그 상태를 쓰는 화면이
    // 현재 없다 — 생기면 그때 웹 렌더를 확인하고 맞춘다.
    final border = variant == AppButtonVariant.outline && isEnabled
        ? Border.all(color: colors.primary500)
        : null;

    // 스크린리더 노출. GestureDetector + Container + Text만으로는
    // TalkBack/VoiceOver가 "버튼"임을 알리지 못하고 비활성도 드러나지 않는다.
    //
    // `excludeSemantics`로 자식(Text)의 중복 라벨 노드를 접고, 그 대신
    // `onTap`을 여기서 직접 노출한다 — 자식을 통째로 접으면 GestureDetector가
    // 만들던 tap 액션까지 사라져 스크린리더로는 누를 수 없는 버튼이 된다.
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      onTap: isEnabled ? onPressed : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: isEnabled ? onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          key: backgroundKeyFor(label),
          width: double.infinity,
          // 웹처럼 높이를 고정한다. 패딩으로 높이를 만들면 폰트 메트릭에 따라
          // 값이 흔들리고, 62개 화면이 그 흔들림을 복사한다.
          height: height,
          decoration: BoxDecoration(
            color: background,
            border: border,
            // 웹 `button.tsx` base의 `rounded-lg` = `var(--radius-l)` = 12px.
            // `rounded-md`(8px)가 아니다 — 입력(`AppTextInput`)이 8px이라
            // 헷갈리기 쉽다.
            borderRadius: BorderRadius.circular(radius.l),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: spacing.s7,
                  height: spacing.s7,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
              : Text(
                  label,
                  // 웹 `button.tsx` 사용처가 붙이는 `Typography.TITLE_1_SEMIBOLD`
                  // (16px/140% semibold). bold(`title1`)가 아니다.
                  // `leadingDistribution: even` — CSS는 여분 행간을 위아래
                  // 절반씩 나누지만(half-leading) Flutter 기본값은 폰트의
                  // ascent/descent 비율로 나눈다. 고정 높이 박스 안에서
                  // Pretendard 한글 글자가 1~2px 어긋나는 원인이다.
                  style: (labelStyle ?? AppTypography.title1SemiBold).copyWith(
                    color: foreground,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
        ),
      ),
    );
  }
}
