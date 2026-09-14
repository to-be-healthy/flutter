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
/// `hasError`로 `enabledBorder`/`border`/`focusedBorder`의 색을 직접
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
        TextField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: AppTypography.body1.copyWith(color: colors.gray800),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: spacing.s6,
              vertical: spacing.s6,
            ),
            filled: true,
            fillColor: colors.gray100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius.m),
              borderSide: hasError
                  ? BorderSide(color: colors.point)
                  : BorderSide.none,
            ),
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
