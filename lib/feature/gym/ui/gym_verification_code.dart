import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../shared/ui/app_otp_input.dart';

/// 웹 `src/feature/mypage/ui/GymVerificationCode.tsx` 대응.
///
/// 자동 포커스는 [AppOtpInput]이 책임진다(웹도 `useEffect`로 마운트 시
/// 입력에 포커스를 준다).
class GymVerificationCode extends StatelessWidget {
  const GymVerificationCode({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 웹 제목의 `mb-[30px]`.
  ///
  /// 예외(토큰화하지 않는 리터럴): 30은 스페이싱 스케일
  /// (4/6/8/10/12/16/20/24/28/32/36/48)에 없는 임의값이다 — 웹도 그래서
  /// 임의값 문법을 썼다.
  static const double titleGap = 30;

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '인증 코드를 입력해 주세요.',
          textAlign: TextAlign.center,
          // 웹 `cn(Typography.HEADING_1, 'mb-[30px] text-center')` —
          // 색 클래스가 없어 기본 foreground로 렌더된다. 헤더 제목과 같은
          // 판단으로 이 팔레트의 본문색을 쓴다(`AppLayoutHeader` 참고).
          style: AppTypography.heading1,
        ),
        const SizedBox(height: titleGap),
        // 웹 `<div className='flex justify-center'>`.
        Center(
          child: AppOtpInput(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
