import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AndroidManifest는 Dart 테스트가 닿지 않는 곳이라 아무것도 지켜주지 않는다.
/// 보안에 영향을 주는 설정 하나를 파일 내용으로 직접 고정한다.
void main() {
  test('Auto Backup을 끈다 (flutter_secure_storage 복원 실패 방지)', () {
    // flutter_secure_storage의 암호화된 prefs는 백업·복원되는데 그것을
    // 복호화할 KeyStore 키는 복원되지 않는다 — 기기 복원 후 읽기에서
    // BadPaddingException이 나는 알려진 실패다. 보안 저장소가 배선되기 전에
    // 막는다. 미설정이면 플랫폼 기본값으로 Auto Backup이 **켜져 있다.**
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android:allowBackup="false"'),
      reason: 'allowBackup을 명시하지 않으면 플랫폼 기본값(true)이 적용된다',
    );
  });
}
