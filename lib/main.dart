import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  // 배포 환경마다 다른 오리진을 빌드 시점에 주입한다:
  // `flutter run --dart-define=API_BASE_URL=https://...`
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://geonganghaejim.site',
  );

  runApp(const GeonganghaejimApp(baseUrl: baseUrl));
}
