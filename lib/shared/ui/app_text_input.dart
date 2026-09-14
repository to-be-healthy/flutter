import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 웹 `src/shared/ui/input` 대응.
///
/// `AppButton`과 동일한 테마 경유 규율을 따른다: 색·간격·라운드는
/// `Theme.of(context).extension<...>()`를 거치고, 타이포는
/// `AppTypography` 정적 상수(=`AppTheme.light()`가 쓰는 값 그 자체)를 쓴다.
///
/// 에러 테두리는 `InputDecoration.errorBorder`(Flutter의 `isError` 플래그가
/// 켜져야만 렌더되는데, 이 위젯은 `errorText`를 `InputDecoration`에 넘기지
/// 않으므로 그 플래그가 절대 켜지지 않아 도달 불가한 죽은 코드였다) 대신
/// `hasError`로 `enabledBorder`/`focusedBorder`의 색을 직접
/// 선택한다. 웹 `SignInForm.tsx`도 테두리 색 전환 + 별도 에러 텍스트를
/// 함께 쓰므로, 에러 메시지는 Flutter가 자동으로 붙이는 캡션이 아니라
/// 아래의 커스텀 `Text`로 그린다.
class AppTextInput extends StatelessWidget {
  const AppTextInput({
    required this.label,
    this.hint,
    this.errorText,
    this.onChanged,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    super.key,
  });

  /// 웹 `SignInForm.tsx:58,81`의 `containerClassName='h-[50px]'` 대응.
  ///
  /// 예외(토큰화하지 않는 리터럴): 50은 `AppSpacing.standard`의 12단
  /// (4/6/8/10/12/16/20/24/28/32/36/48) 어디에도 없다 — 웹도 같은 이유로
  /// 스페이싱 클래스 대신 임의값 문법(`h-[50px]`)을 썼다. 입력 높이는 간격
  /// 토큰이 아니라 이 컴포넌트 고유의 고정 치수다.
  static const double height = 50;

  /// `AppTypography.body1`의 실제 행 높이(16 × 1.5 = 24).
  ///
  /// 세로 패딩을 이 값에서 역산하므로, 타이포가 바뀌면 "입력 높이는 웹
  /// h-[50px]와 같다" 테스트가 먼저 깨진다 — 화면에서 어긋나기 전에 잡힌다.
  static final double _lineHeight =
      AppTypography.body1.fontSize! * AppTypography.body1.height!;

  final String label;

  /// 웹 `TextInput`의 `placeholder`. 웹은 `placeholder:text-gray-500`로
  /// BODY_1을 gray-500으로 깐다(`TextInput.tsx`의 `twSelector('placeholder',
  /// Typography.BODY_1)`).
  final String? hint;

  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          // 웹 `SignInForm.tsx:50,74` = `cn(Typography.TITLE_3,
          // 'text-gray-800')`. gray700이 아니다.
          style: AppTypography.title3.copyWith(color: colors.gray800),
        ),
        SizedBox(height: spacing.s3),
        TextField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textAlignVertical: TextAlignVertical.center,
          // `leadingDistribution: even` — CSS는 여분 행간을 위아래 절반씩
          // 나누지만(half-leading) Flutter 기본값은 폰트의 ascent/descent
          // 비율로 나눈다. 고정 높이 박스 안에서 Pretendard 한글 글자가
          // 1~2px 어긋나는 원인이다.
          style: AppTypography.body1.copyWith(
            color: colors.gray800,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppTypography.body1.copyWith(
              color: colors.gray500,
              leadingDistribution: TextLeadingDistribution.even,
            ),
            // 웹 `h-[50px]`. 높이는 **세로 패딩으로** 만든다.
            //
            // 바깥 `SizedBox(height: 50)`로는 만들 수 없다 — `InputDecorator`는
            // 채움·테두리 상자의 높이를 콘텐츠에서 계산하고 바깥 제약으로
            // 늘리지 않는다(`expands: true`가 그 역할이지만 `obscureText`와
            // 동시에 쓸 수 없어 비밀번호 입력에는 못 쓴다). 시뮬레이터 실측에서
            // 24pt 상자가 50pt 슬롯 가운데 떠 있었고, 남은 26pt가 필드 사이
            // 간격을 웹 53pt → 79pt로 벌렸다. 위젯 테스트는 `SizedBox`의
            // 50pt만 재고 있어 이 어긋남을 통과시켰다.
            contentPadding: EdgeInsets.symmetric(
              horizontal: spacing.s6,
              vertical: (height - _lineHeight) / 2,
            ),
            // 웹 입력에는 배경이 없다 — `TextInput.tsx`의 클래스에 `bg-*`가
            // 없어 페이지 배경이 그대로 비친다. gray-100은 웹에서 **비활성**
            // 색(`disabled:bg-gray-100`)이라, 평상시에 칠하면 62개 화면의
            // 모든 입력이 비활성처럼 보인다.
            filled: false,
            // `border:`는 두지 않는다 — `enabledBorder`가 항상 이겨 도달
            // 불가한 죽은 분기이고, 62개 화면이 이 위젯을 복사한다.
            // (부작용: 나중에 `enabled: false`를 붙이면 `disabledBorder`가
            // Material 기본 `UnderlineInputBorder`로 떨어지므로, 비활성
            // 입력을 추가할 때 `disabledBorder`를 명시할 것.)
            enabledBorder: OutlineInputBorder(
              // 웹 입력의 `rounded-md` = `var(--radius-m)` = 8px.
              borderRadius: BorderRadius.circular(radius.m),
              // 웹 `border border-solid border-gray-200`. 에러일 때만
              // point로 바뀐다(`SignInForm.tsx`의 `border-point`).
              borderSide: BorderSide(
                color: hasError ? colors.point : colors.gray200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius.m),
              borderSide: BorderSide(
                color: hasError ? colors.point : colors.primary500,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          // 라벨과 같은 8px이다. 웹은 라벨·입력·에러를 **한 컨테이너의
          // `gap-y-3`**로 묶으므로 세 사이 간격이 전부 같다
          // (`SignInForm.tsx`의 `flex flex-col gap-y-3`, `FindIdPage.tsx`의
          // `flex flex-col gap-3`). 6px이던 이전 값은 근거 없는 어긋남이었다.
          SizedBox(height: spacing.s3),
          Text(
            errorText!,
            style: AppTypography.body4.copyWith(color: colors.point),
          ),
        ],
      ],
    );
  }
}
