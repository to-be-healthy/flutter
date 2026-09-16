import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 웹 마이페이지 편집 폼의 입력 상자.
///
/// ```tsx
/// <div className='rounded-md border border-gray-200 px-6 py-[13px]'>
///   <Input className='w-full' ... />
/// </div>
/// ```
///
/// ## [AppTextInput]과 무엇이 다른가
///
/// | | `AppTextInput` | 이 위젯 |
/// |---|---|---|
/// | 라벨 | 위에 붙는다(필수) | **없다** |
/// | 에러 문구 | 아래에 붙는다 | 없다(화면이 토스트로 낸다) |
/// | 높이 | 50 | **52** |
///
/// 웹이 두 모양을 실제로 나눠 쓴다. 로그인·찾기 화면은 라벨 있는 입력을
/// 쓰고, 마이페이지 편집 폼은 **섹션 제목(`<h3>`)이 따로 있어서** 입력에
/// 라벨을 붙이지 않는다. 제목은 입력의 라벨이 아니다.
///
/// ## 치수 (2026-09-15 브라우저 실측)
///
/// 상자 `400 × 52` — `py-[13px]` 둘 + 줄 높이 24 + 테두리 2.
/// 안쪽 `<input>`은 `366 × 24`(400 − 좌우 패딩 32 − 테두리 2).
/// 모서리 8(`rounded-md`), 테두리 `#DEE1E6`(gray-200),
/// 플레이스홀더 `#A7A9AE`(gray-400).
///
/// ## 사용처
///
/// `/student/mypage/edit/password`(3개) · `/student/mypage/edit/name`(1개).
/// `/student/mypage/edit/email`도 같은 모양이다.
class AppPlainInput extends StatelessWidget {
  const AppPlainInput({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.obscureText = false,
    this.readOnly = false,
    super.key,
  });

  /// 웹 `py-[13px]`.
  ///
  /// 예외(토큰화하지 않는 리터럴): 13은 `AppSpacing.standard`의 12단
  /// 어디에도 없다 — 웹도 같은 이유로 임의값 문법을 썼다.
  static const double verticalPadding = 13;

  /// 상자의 렌더 높이. 테스트가 이 값을 리터럴로 단언한다(규율 #18).
  static const double height = 52;

  final String hint;
  final ValueChanged<String> onChanged;

  /// 초기값을 넣어야 하는 화면만 넘긴다(`/edit/name`이 현재 이름을 채운다).
  ///
  /// **넘기지 않으면 `TextField`가 자기 상태로 글자를 들고 있다.** 그것이
  /// `/edit/password`가 웹의 비제어 입력 동작(실패해도 글자가 남는다)을
  /// 재현하는 방법이다 — 컨트롤러를 붙이면 그 동작이 달라진다.
  final TextEditingController? controller;

  final bool obscureText;

  /// 웹 `readOnly` 속성.
  ///
  /// **`disabled`가 아니다** — 회색으로 흐려지지 않고 테두리도 그대로다.
  /// `/edit/email`의 2단계가 이메일 칸을 이렇게 잠근다.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radius = theme.extension<AppRadius>()!;

    return Container(
      // 웹 `px-6 py-[13px]` = 좌우 16, 상하 13.
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s6,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        // 웹 `rounded-md` = 8. 버튼(`rounded-lg` = 12)과 다르다.
        borderRadius: BorderRadius.circular(radius.m),
        border: Border.all(color: colors.gray200),
      ),
      // 부모가 높이를 정해 주면(`IntrinsicHeight` + `stretch`) 그 높이를
      // 꽉 채우고 **내용을 위에 붙인다.** `/edit/email`의 인증번호 행이
      // 그런 경우다 — 옆의 `재전송` 버튼(56)이 행 높이를 끌어올리는데,
      // 웹에서도 늘어난 상자 안의 `<input>`은 위에 붙는다(실측: 상자 56,
      // 입력 24, 위 여백 13, 아래 17).
      //
      // 높이 상한이 없는 보통의 경우에는 `Align`이 자식 크기를 따라가므로
      // 이 정렬이 아무것도 바꾸지 않는다(다른 두 화면은 52 그대로다).
      alignment: Alignment.topLeft,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onChanged: onChanged,
        style: AppTypography.body1,
        decoration: InputDecoration(
          hintText: hint,
          // 웹 플레이스홀더 색 실측: `#A7A9AE`(= gray-400).
          hintStyle: AppTypography.body1.copyWith(color: colors.gray400),
          // 테두리·패딩은 바깥 `Container`가 그린다. `TextField`가 자기
          // 테두리와 기본 패딩(12~16)을 더하면 상자가 52를 넘는다.
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
