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
}
