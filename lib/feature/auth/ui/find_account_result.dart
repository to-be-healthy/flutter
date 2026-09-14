import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 웹 두 화면의 결과 분기가 공유하는 레이아웃
/// (`<div className='mt-[200px] flex flex-col items-center gap-11 px-[63px]'>`).
///
/// 네 개의 결과 분기 중 셋이 이 모양이다 — 아이디 찾기의 소셜 분기,
/// 비밀번호 찾기의 일반·소셜 분기. 아이디 찾기의 일반 분기만 다른 모양
/// (파란 카드)이라 그 화면이 직접 그린다.
class FindAccountResult extends StatelessWidget {
  const FindAccountResult({
    required this.icon,
    required this.message,
    super.key,
  });

  /// 웹 `mt-[200px]`.
  static const double topGap = 200;

  /// 웹 안쪽 `<div>`의 `px-[63px]`. 바깥 `Layout.Contents`의 `px-7`(20px)에
  /// **더해지므로** 실제 좌우 여백은 83px이다.
  static const double innerHorizontalPadding = 63;

  /// [AppSocialIcon] 또는 `love_letter.svg`.
  final Widget icon;
  final Widget message;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Padding(
      // 웹 `<Layout.Contents className='px-7'>`.
      padding: EdgeInsets.symmetric(horizontal: spacing.s7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: topGap),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: innerHorizontalPadding,
            ),
            child: Column(
              children: [
                icon,
                // 웹 `gap-11` = 36px.
                SizedBox(height: spacing.s11),
                message,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 결과 문구. 이메일만 primary 색이고 나머지는 검정이다
/// (`<span className='text-primary'>{email}</span>` + 본문).
///
/// 웹은 `whitespace-pre-wrap break-keep text-center`다 — 줄바꿈 문자를
/// 살리고(소셜 분기의 `{'\n'}`), 한국어 단어를 쪼개지 않으며, 가운데 정렬.
/// Flutter의 기본 줄바꿈은 이미 단어 단위라 `break-keep`에 대응하는 설정이
/// 따로 필요 없다.
class FindAccountMessage extends StatelessWidget {
  const FindAccountMessage({
    required this.email,
    required this.suffix,
    super.key,
  });

  /// 소셜 계정 안내. 웹: `{email}은\n{provider} 계정으로 가입되어 있습니다.`
  factory FindAccountMessage.social({
    required String email,
    required String providerName,
  }) {
    return FindAccountMessage(
      email: email,
      suffix: '은\n$providerName 계정으로 가입되어 있습니다.',
    );
  }

  /// 비밀번호 발송 안내. 웹: `{email}으로 초기화된 비밀번호가 발송되었습니다.`
  factory FindAccountMessage.passwordSent({required String email}) {
    return FindAccountMessage(email: email, suffix: '으로 초기화된 비밀번호가 발송되었습니다.');
  }

  final String email;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: email,
            // 웹 `text-primary` = `var(--primary-500)`
            // (tailwind.config의 `primary.DEFAULT`).
            style: TextStyle(color: colors.primary500),
          ),
          TextSpan(text: suffix),
        ],
      ),
      textAlign: TextAlign.center,
      // 웹 `Typography.TITLE_1_SEMIBOLD` + `text-black`.
      //
      // 예외(토큰화하지 않는 리터럴): `Colors.black`은 웹 `text-black`
      // (`#000`)에 대응하는 프레임워크 상수다. `AppColors`의 가장 어두운
      // 값은 gray800(`#2E3134`)이라 이 색이 아니다 — 온보딩 화면의
      // 역할 선택 타일과 같은 예외다.
      style: AppTypography.title1SemiBold.copyWith(color: Colors.black),
    );
  }
}
