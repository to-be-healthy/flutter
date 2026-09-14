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
/// `BorderSide.none`은 대응 토큰이 없는 프레임워크 상수라 리터럴로 남긴다.
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

  final String label;
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
        // 웹처럼 높이를 고정한다. 패딩으로 높이를 만들면 폰트 메트릭에 따라
        // 값이 흔들리고, 62개 화면이 그 흔들림을 복사한다. 세로 정렬은
        // `textAlignVertical`이 맡으므로 세로 패딩은 주지 않는다.
        SizedBox(
          height: height,
          child: TextField(
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
              contentPadding: EdgeInsets.symmetric(horizontal: spacing.s6),
              filled: true,
              fillColor: colors.gray100,
              // `border:`는 두지 않는다 — `enabledBorder`가 항상 이겨 도달
              // 불가한 죽은 분기이고, 62개 화면이 이 위젯을 복사한다.
              // (부작용: 나중에 `enabled: false`를 붙이면 `disabledBorder`가
              // Material 기본 `UnderlineInputBorder`로 떨어지므로, 비활성
              // 입력을 추가할 때 `disabledBorder`를 명시할 것.)
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius.m),
                borderSide: hasError
                    ? BorderSide(color: colors.point)
                    : BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius.m),
                borderSide: BorderSide(
                  color: hasError ? colors.point : colors.primary500,
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: spacing.s2),
          Text(
            errorText!,
            style: AppTypography.body4.copyWith(color: colors.point),
          ),
        ],
      ],
    );
  }
}
