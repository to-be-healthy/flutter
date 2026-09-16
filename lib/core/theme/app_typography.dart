import 'package:flutter/material.dart';

/// 웹 `src/shared/mixin/typography.ts` 대응.
///
/// 웹 상수 19개 중 아래 3쌍은 값이 동일한 별칭이라 통합했다:
/// HEADING_4 == HEADING_4_BOLD, TITLE_1 == TITLE_1_BOLD,
/// BODY_4 == BODY_4_REGULAR.
///
/// Tailwind `text-[24px]/[130%]`의 130%는 line-height 비율이고
/// Flutter `height`는 배수이므로 1.3으로 옮긴다.
abstract final class AppTypography {
  /// 글꼴 이름. `AppButton.baseLabel`처럼 이 클래스 밖에서 웹 기본
  /// 스타일을 정의하는 곳이 있어 공개한다.
  static const String family = 'Pretendard';
  static const String _family = family;

  /// **모든 스타일이 자간을 0으로 못박는다.**
  ///
  /// 이 값을 주지 않으면 Material 3의 `textTheme.bodyMedium`이 `Scaffold`
  /// 안에서 `DefaultTextStyle`로 상속되고, 그 기본 자간 **0.25**가 여기
  /// 스타일들에 섞인다(`TextStyle.inherit`가 기본 true라 병합된다).
  ///
  /// 웹에는 `letter-spacing` 선언이 없다 — 즉 `normal`(0)이다. 실측:
  /// `수업일지`(4자, 16px)가 웹 **55.31**인데 앱에서 **56.31**이 나왔다.
  /// 글자당 0.25px라 한 줄에서는 안 보이지만, **고정 폭 안에 텍스트가
  /// 들어가는 레이아웃에서는 그 누적이 곧 오버플로다** — 마이페이지 허브의
  /// 320px 바로가기 카드가 정확히 0.78px 넘쳤다.
  static const double _letterSpacing = 0;

  static const TextStyle heading1 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 22,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading4SemiBold = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle heading5 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title1 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle title1SemiBold = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title3 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body3 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body4 = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body4Medium = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );

  /// 웹 NAV_TEXT. line-height 미지정이라 height를 두지 않는다.
  static const TextStyle navText = TextStyle(
    fontFamily: _family,
    letterSpacing: _letterSpacing,
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  static const List<TextStyle> all = [
    heading1,
    heading2,
    heading3,
    heading4,
    heading4SemiBold,
    heading5,
    title1,
    title1SemiBold,
    title2,
    title3,
    body1,
    body2,
    body3,
    body4,
    body4Medium,
    navText,
  ];
}
