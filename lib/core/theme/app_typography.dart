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
  static const String _family = 'Pretendard';

  static const TextStyle heading1 = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading4SemiBold = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle heading5 = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title1 = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle title1SemiBold = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title3 = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body3 = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body4 = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body4Medium = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );

  /// 웹 NAV_TEXT. line-height 미지정이라 height를 두지 않는다.
  static const TextStyle navText = TextStyle(
    fontFamily: _family,
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
