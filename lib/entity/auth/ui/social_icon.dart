import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';

/// 웹 `src/entity/auth/ui/SocialIcon.tsx`의 `socialProviders` 대응.
///
/// 키는 백엔드 `socialType` 값 그대로다('NONE'은 소셜 가입이 아니라
/// 여기 없다 — 웹도 `Exclude<SocialType, 'NONE'>`으로 타입에서 뺀다).
@immutable
class SocialProvider {
  const SocialProvider({
    required this.name,
    required this.asset,
    required this.assetWidth,
    required this.assetHeight,
    this.background,
    this.hasBorder = false,
  });

  /// 화면에 그대로 노출되는 한글 이름("…계정으로 가입되어 있습니다").
  final String name;

  final String asset;

  /// 자산의 고유 크기. 넷이 제각각이다 — 네이버·애플 자산은 원형 배경까지
  /// 그려진 44pt 배지이고, 구글·카카오 자산은 가운데 놓일 글리프만 있다.
  final double assetWidth;
  final double assetHeight;

  /// 웹 래퍼 `<span>`의 `bg-*`. 구글만 배경 없이 테두리를 쓴다.
  ///
  /// 예외(토큰화하지 않는 리터럴): 이 값들은 디자인 팔레트가 아니라
  /// **각 사업자의 브랜드 색**이다(`bg-[#03C75A]` 처럼 웹도 임의값 문법으로
  /// 박아 뒀다). `AppColors`에 넣으면 팔레트를 오염시킨다.
  final Color? background;

  /// 웹 구글의 `border border-gray-200`.
  final bool hasBorder;
}

const Map<String, SocialProvider> socialProviders = <String, SocialProvider>{
  'NAVER': SocialProvider(
    name: '네이버',
    asset: 'assets/images/naver_logo_circle.svg',
    assetWidth: 44,
    // 자산 고유 높이가 45다(원이 1px 삐져나온다). 웹도 44×44 span 안에
    // 그대로 그려 같은 삐짐이 있다.
    assetHeight: 45,
    background: Color(0xFF03C75A),
  ),
  'GOOGLE': SocialProvider(
    name: '구글',
    asset: 'assets/images/google_logo_circle.svg',
    assetWidth: 22,
    assetHeight: 21,
    hasBorder: true,
  ),
  'KAKAO': SocialProvider(
    name: '카카오',
    asset: 'assets/images/kakao_logo_circle.svg',
    assetWidth: 26,
    assetHeight: 26,
    background: Color(0xFFFEE500),
  ),
  'APPLE': SocialProvider(
    name: '애플',
    asset: 'assets/images/apple_logo.svg',
    assetWidth: 44,
    assetHeight: 44,
    background: Color(0xFF000000),
  ),
};

/// 웹 `<SocialIcon socialType={...} />` 대응.
///
/// 웹은 `socialProviders[socialType]`을 무조건 찾아 쓰기 때문에 'NONE'이나
/// 모르는 값이 오면 런타임에 터진다. 앱에서는 화면을 던지는 대신 빈 자리만
/// 남긴다 — 백엔드에 소셜 제공자가 추가되면 앱 업데이트 전까지 이 값이
/// 내려올 수 있고, 그때 화면 전체가 죽는 것보다 아이콘 하나가 비는 게 낫다.
class AppSocialIcon extends StatelessWidget {
  const AppSocialIcon({required this.socialType, super.key});

  /// 'NAVER' | 'GOOGLE' | 'KAKAO' | 'APPLE'.
  final String socialType;

  /// 웹 래퍼 `<span className='h-[44px] w-[44px] rounded-full'>`.
  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final provider = socialProviders[socialType];
    if (provider == null) {
      return const SizedBox(width: size, height: size);
    }

    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: provider.background,
        shape: BoxShape.circle,
        border: provider.hasBorder ? Border.all(color: colors.gray200) : null,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        provider.asset,
        width: provider.assetWidth,
        height: provider.assetHeight,
      ),
    );
  }
}
