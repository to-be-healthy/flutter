import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// `pubspec.yaml`이 `assets/images/`를 통째로 선언하므로 파일을 떨어뜨리기만
/// 하면 **번들에는 들어간다.** 문제는 그다음이다 — 파싱에 실패한 SVG는
/// 예외를 던지지 않고 **빈 상자로 조용히 렌더된다.** 위젯 테스트는 위젯이
/// 트리에 있는지만 보므로 그 상태를 통과시킨다(Phase 1 원장에 같은 경고를
/// 적어 뒀다: "위젯 테스트의 '파싱됨'은 '보인다'가 아니다").
///
/// 여기서는 `SvgAssetLoader`를 직접 돌려 **렌더 시점에 일어나는 그 컴파일**을
/// 앞당긴다. Figma 내보내기가 흔히 남기는 `clip-path`·`<use>`·gradient 중
/// flutter_svg가 못 다루는 것이 섞여 들어오면 여기서 먼저 깨진다.
///
/// 자산을 추가하면 **이 목록에도 넣어라.** 목록을 디렉터리 순회로 바꾸지
/// 않는 이유는, 순회는 "지금 있는 것"만 검사해서 자산을 지웠을 때 아무도
/// 알려주지 않기 때문이다 — 화면 코드가 참조하는 경로를 손으로 적어야
/// 삭제도 잡힌다.
const List<String> _svgAssets = <String>[
  'assets/images/logo.svg',
  'assets/images/back.svg',
  'assets/images/close.svg',
  'assets/images/error.svg',
  'assets/images/love_letter.svg',
  'assets/images/naver_logo_circle.svg',
  'assets/images/google_logo_circle.svg',
  'assets/images/kakao_logo_circle.svg',
  'assets/images/apple_logo.svg',
  'assets/images/arrow_right_small.svg',
  // `/student` 홈 (2026-09-15). 헤더·네비·카드에서 쓴다.
  'assets/images/alarm.svg',
  'assets/images/arrow_down.svg',
  'assets/images/arrow_filled_down.svg',
  'assets/images/arrow_filled_up.svg',
  'assets/images/avatar.svg',
  'assets/images/check.svg',
  'assets/images/plus.svg',
  'assets/images/home_filled.svg',
  'assets/images/home_outlined.svg',
  'assets/images/calendar_filled.svg',
  'assets/images/calendar_outlined.svg',
  'assets/images/community_filled.svg',
  'assets/images/community_outlined.svg',
  'assets/images/profile_filled.svg',
  'assets/images/profile_outlined.svg',
  // `/trainer` 홈 (2026-09-15).
  'assets/images/alarm_white.svg',
  'assets/images/calendar_x.svg',
  'assets/images/medal_gold.svg',
  // 회원 마이페이지 허브 (2026-09-15). 3분할 바로가기 카드에서 쓴다.
  // 셋 다 리터럴 색이라 `fill="current"` 함정(규율 #13)이 없다 —
  // 가져올 때 `grep -l 'fill="current"'`로 확인했다.
  'assets/images/class_log.svg',
  'assets/images/diet.svg',
  'assets/images/exercise_log.svg',
  // 회원 마이페이지 · 내 정보 (2026-09-15).
  // `camera.svg`는 원본에 `fill="current"`가 있어 정규화했다 —
  // 아래 `currentColor 정규화` 그룹이 실제로 그려지는지까지 확인한다.
  'assets/images/camera.svg',
  'assets/images/kakao_logo.svg',
  'assets/images/google_logo.svg',
  'assets/images/naver_logo.svg',
  // 회원 탈퇴 (2026-09-15). 원본에 `fill="current"`가 있어 정규화했다 —
  // 아래 `currentColor 정규화` 그룹이 실제로 그려지는지까지 확인한다.
  'assets/images/no_circle_check.svg',
  // 트레이너 정보 빈 상태 (2026-09-15). 리터럴 색이라 함정이 없다.
  'assets/images/alert_circle.svg',
  // 지난 예약 (2026-09-15). 두 화살표는 원본에 `stroke="current"`가 있어
  // 정규화했다 — 아래 `currentColor 정규화` 그룹이 렌더까지 확인한다.
  'assets/images/no_schedule.svg',
  'assets/images/icon_triangle_down.svg',
  'assets/images/icon_arrow_left.svg',
  'assets/images/icon_arrow_right.svg',
  // 트레이너 · 나의 회원 (2026-09-15). 여섯 개 전부 리터럴 색이라 규율 #13의
  // `fill="current"` 함정이 없다 — 가져오면서 grep으로 확인했다.
  // `profile_default.svg`와 `icon_close.svg`에는 루트에 `width="current"`가
  // 있지만 그쪽은 viewBox가 대신하므로 무해하다(서베이 §6.4 ②).
  'assets/images/search.svg',
  'assets/images/profile_default.svg',
  'assets/images/icon_arrow_down_up.svg',
  'assets/images/icon_close.svg',
  'assets/images/people_plus.svg',
  'assets/images/peoples.svg',
  // 트레이너 · 회원 정보 (2026-09-16). 다섯 개 다 리터럴 색이고,
  // **고유 크기가 브라우저 실측과 정확히 같다**(4×16 / 82×82 / 19×18 /
  // 21×20 / 20×11) — 웹이 이 아이콘들에 크기 prop을 주지 않아 자산의
  // viewBox가 그대로 렌더 크기가 되기 때문이다.
  'assets/images/dots_vertical.svg',
  'assets/images/icon_default_profile.svg',
  'assets/images/icon_calendar_blue.svg',
  'assets/images/icon_edit.svg',
  'assets/images/icon_dumbel.svg',
  // 수강권 내역 빈 상태(S3). 웹 `notification.svg` — 원본이 `stroke="current"`라
  // 그대로 들여왔으면 flutter_svg에서 **한 획도 안 그려진다**(규율 #13).
  // `currentColor`로 정규화해 이식했고, 화면이 `SvgTheme(currentColor:)`로
  // 웹의 `stroke='var(--gray-300)'`를 주입한다.
  'assets/images/notification.svg',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SVG 자산', () {
    for (final asset in _svgAssets) {
      test('$asset 을 그릴 수 있다', () async {
        final loader = SvgAssetLoader(asset);

        // 번들에서 읽어 vector_graphics 바이트로 컴파일한다 —
        // `SvgPicture.asset`이 렌더 직전에 하는 일과 같다.
        final bytes = await loader.loadBytes(null);

        expect(
          bytes.lengthInBytes,
          greaterThan(0),
          reason: '$asset 이 빈 그림으로 컴파일됐다 — 화면에는 빈 상자로 보인다',
        );
      });
    }
  });

  group('currentColor 정규화', () {
    // 웹에서 가져온 원본은 `fill="current"`(유효하지 않은 값)를 쓴다.
    // 브라우저는 유효하지 않은 표현 속성을 **무시하고 부모 값을 상속**해서,
    // SVGR 컴포넌트에 넘긴 `fill` prop 색이 그대로 내려온다. flutter_svg는
    // 상속 대신 **칠하지 않음**으로 처리해서 아이콘이 통째로 사라진다
    // (실측: `arrow_filled_up.svg`가 한 픽셀도 그려지지 않았다).
    //
    // 그래서 복사한 자산의 페인트 속성을 표준 `currentColor`로 정규화하고,
    // 화면은 `SvgTheme(currentColor:)`로 웹이 prop에 넘기던 색을 주입한다.
    // 자산을 다시 그린 것이 아니라 **브라우저가 실제로 하는 해석을 명시한**
    // 것이다.
    //
    // 이 테스트가 지키는 것: 누군가 웹에서 자산을 다시 복사해 `current`가
    // 돌아오면 아이콘이 조용히 사라지는데, 위 컴파일 테스트는 그래도
    // 통과한다("파싱됨"은 "보인다"가 아니다 — 규율 #8).
    const Map<String, String> currentColorAssets = <String, String>{
      'assets/images/check.svg': "웹 `IconCheck fill='var(--primary-500)'`",
      'assets/images/plus.svg': "웹 `IconPlus fill='var(--gray-500)'`",
      'assets/images/arrow_filled_down.svg':
          "웹 `IconArrowFilledDown fill='var(--primary-500)'`",
      'assets/images/arrow_filled_up.svg':
          "웹 `IconArrowFilledUp fill='var(--point-color)'`",
      'assets/images/camera.svg': "웹 `IconCamera fill='var(--gray-500)'`",
      'assets/images/no_circle_check.svg': "웹 `NoCircleCheckIcon fill='white'`",
      'assets/images/icon_arrow_left.svg':
          "웹 MonthPicker `IconArrowLeft stroke='var(--primary-500)'`",
      'assets/images/icon_arrow_right.svg':
          "웹 MonthPicker `IconArrowRight` — 연도 상한이면 gray-500",
    };

    /// [asset]을 [currentColor]로 그려서, 그 색으로 칠해진 픽셀 수를 센다.
    Future<int> pixelsPainted(String asset, Color currentColor) async {
      final info = await vg.loadPicture(
        SvgAssetLoader(asset, theme: SvgTheme(currentColor: currentColor)),
        null,
      );
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawPicture(info.picture);
      final image = await recorder.endRecording().toImage(64, 64);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();

      var painted = 0;
      for (var i = 0; i < bytes.length; i += 4) {
        // 안티에일리어싱 경계를 빼고 **정확히 그 색인** 픽셀만 센다.
        if (bytes[i + 3] == 255 &&
            bytes[i] == (currentColor.r * 255).round() &&
            bytes[i + 1] == (currentColor.g * 255).round() &&
            bytes[i + 2] == (currentColor.b * 255).round()) {
          painted++;
        }
      }
      return painted;
    }

    // 두 색으로 각각 그려 **둘 다** 그 색이 나오는지 본다. 한 색만 보면
    // 자산에 그 색이 박혀 있는 경우(정규화가 풀렸는데 우연히 통과)를
    // 구별하지 못한다.
    const Color red = Color(0xFFFF0000);
    const Color green = Color(0xFF00FF00);

    currentColorAssets.forEach((asset, origin) {
      test('$asset 이 currentColor 를 따른다 ($origin)', () async {
        expect(
          await pixelsPainted(asset, red),
          greaterThan(10),
          reason:
              '$asset 이 주입한 색으로 칠해지지 않았다. `fill="current"`가 '
              '돌아왔는지 확인하라 — flutter_svg 는 그 값을 "칠하지 않음"으로 '
              '처리해서 아이콘이 통째로 사라진다.',
        );
        expect(
          await pixelsPainted(asset, green),
          greaterThan(10),
          reason: '$asset 이 한 색에만 반응한다 — 색이 자산에 박혀 있다.',
        );
      });
    });
  });
}
