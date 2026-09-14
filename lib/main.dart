import 'package:flutter/material.dart';

import 'app.dart';
import 'core/router/app_router.dart';

void main() {
  // 배포 환경마다 다른 오리진을 빌드 시점에 주입한다:
  // `flutter run --dart-define=API_BASE_URL=https://...`
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://geonganghaejim.site',
  );

  // 앱이 처음 여는 경로도 빌드 시점에 바꿀 수 있게 열어 둔다:
  // `flutter run --dart-define=INITIAL_LOCATION=/find/id`
  //
  // **디바이스 대조용이다.** 62개 화면을 옮기는 동안 특정 화면을 실기기에서
  // 확인하려면 매번 로그인·탭 여러 번을 거쳐야 한다. 기본값이 웹 `/`와 같고
  // `String.fromEnvironment`는 컴파일 타임 상수라, define 없이 만든
  // 배포 빌드에는 이 경로가 존재하지 않는다.
  const initialLocation = String.fromEnvironment(
    'INITIAL_LOCATION',
    defaultValue: AppRoutes.onboarding,
  );

  runApp(
    const GeonganghaejimApp(baseUrl: baseUrl, initialLocation: initialLocation),
  );
}
