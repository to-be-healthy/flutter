import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 모든 테스트 앞에 **실제 Pretendard를 싣는다.**
///
/// ## 왜 필요한가
///
/// `flutter test`의 기본 글꼴은 플랫폼 간 결정성을 위해 **모든 글자를 1em
/// 정사각형으로** 그리는 테스트 폰트다. 앱이 `pubspec.yaml`에 선언한 글꼴은
/// 자동으로 실리지 않는다.
///
/// 그래서 글자 폭이 실기기와 다르다. 실측(2026-09-15):
///
/// | | 테스트 기본 글꼴 | 실제 Pretendard(웹 `getBoundingClientRect`) |
/// |---|---|---|
/// | `수업일지`(4자, 16px) | **64.0** | **55.31** |
/// | `식단`(2자, 16px) | **32.0** | **27.66** |
///
/// 글자당 16px 대 13.83px, **17% 차이**다. 고정 폭 안에 텍스트가 들어가는
/// 레이아웃에서는 이 차이가 곧 오버플로다 — 마이페이지 허브의 320px 바로가기
/// 카드가 실제로 그랬다. 웹에서는 318.28로 들어맞는데 테스트에서만 23px
/// 넘쳤고, **실기기에서는 넘치지 않는다.**
///
/// 글꼴을 싣지 않으면 두 방향으로 틀린다:
/// - **거짓 양성** — 실기기에서 멀쩡한 화면이 테스트에서 넘친다. 그것을
///   고치려고 웹에 없는 `Flexible`·축약을 넣으면 화면이 웹과 달라진다.
/// - **거짓 음성** — 테스트 글꼴이 더 좁은 경우(영문·숫자) 실기기에서만
///   넘친다. 폰 너비 테스트(규율 #14)가 그 자리를 못 잡는다.
///
/// ## 무게
///
/// `AppTypography`가 쓰는 네 무게만 싣는다(400·500·600·700). `FontLoader`는
/// 같은 family로 등록된 파일들의 **내부 메타데이터**로 무게를 고른다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = FontLoader('Pretendard');
  const weights = <String>['Regular', 'Medium', 'SemiBold', 'Bold'];
  for (final weight in weights) {
    loader.addFont(
      File('assets/fonts/Pretendard-$weight.otf').readAsBytes().then(
        (bytes) => ByteData.view(Uint8List.fromList(bytes).buffer),
      ),
    );
  }
  await loader.load();

  await testMain();
}
