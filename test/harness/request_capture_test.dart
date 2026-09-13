import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_capture.dart';

void main() {
  group('RequestCapture', () {
    test('실제 dio 요청의 method·path·query·body를 캡처한다', () async {
      final capture = RequestCapture();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..interceptors.add(capture)
        ..httpClientAdapter = _StubAdapter();

      await dio.post<dynamic>(
        '/api/v1/members/login',
        data: {'email': 'test@example.com', 'password': 'password1234'},
      );
      await dio.get<dynamic>(
        '/api/v1/workouts',
        queryParameters: {'page': 0, 'size': 20},
      );

      expect(capture.captured, hasLength(2));

      final login = capture.captured.first;
      expect(login.method, 'POST');
      expect(login.path, '/api/v1/members/login');
      expect(login.query, isEmpty);
      expect(login.body, {
        'email': 'test@example.com',
        'password': 'password1234',
      });

      final list = capture.captured[1];
      expect(list.method, 'GET');
      expect(list.path, '/api/v1/workouts');
      expect(list.query, {'page': 0, 'size': 20});
      expect(list.body, isNull);
    });

    test('captured는 외부에서 수정할 수 없고 clear로 비운다', () async {
      final capture = RequestCapture();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..interceptors.add(capture)
        ..httpClientAdapter = _StubAdapter();

      await dio.get<dynamic>('/api/v1/ping');
      expect(capture.captured, hasLength(1));

      expect(
        () => capture.captured.add(capture.captured.first),
        throwsUnsupportedError,
      );

      capture.clear();
      expect(capture.captured, isEmpty);
    });
  });
}

/// 네트워크에 나가지 않고 빈 JSON 200을 돌려주는 테스트용 어댑터.
class _StubAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
