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

    test('본문이 있는 POST는 content-type 헤더를 캡처한다', () async {
      final capture = RequestCapture();
      final dio =
          Dio(
              BaseOptions(
                baseUrl: 'https://api.example.com',
                contentType: Headers.jsonContentType,
              ),
            )
            ..interceptors.add(capture)
            ..httpClientAdapter = _StubAdapter();

      await dio.post<dynamic>('/api/v1/auth/login', data: {'userId': 'a'});

      // 값까지 비교 대상이다 — 백엔드 스펙(application/json;charset=UTF-8)과
      // dio 기본값의 차이가 골든 대조에서 드러나야 한다.
      expect(
        capture.captured.single.headers['content-type'],
        'application/json',
      );
    });

    test('본문 없는 GET에도 content-type이 붙는다 (DioClient 전역 설정의 결과)', () async {
      // 브라우저는 본문 없는 GET에 content-type을 붙이지 않는다. dio는
      // `BaseOptions.contentType`을 헤더 맵에 그대로 넣으므로 붙는다.
      // **이 사실을 여기서 고정한다** — 골든 대조에서 GET마다 차이가 나면
      // 원인이 하네스가 아니라 DioClient임을 이 테스트가 증명한다.
      final capture = RequestCapture();
      final dio =
          Dio(
              BaseOptions(
                baseUrl: 'https://api.example.com',
                contentType: Headers.jsonContentType,
              ),
            )
            ..interceptors.add(capture)
            ..httpClientAdapter = _StubAdapter();

      await dio.get<dynamic>('/api/v1/members/me');

      expect(
        capture.captured.single.headers['content-type'],
        'application/json',
      );
    });

    test('Authorization 헤더를 캡처한다 (붙지 않는 화면과 구별하기 위해)', () async {
      final capture = RequestCapture();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..interceptors.add(capture)
        ..httpClientAdapter = _StubAdapter();

      await dio.get<dynamic>(
        '/api/v1/members/me',
        options: Options(headers: {'Authorization': 'Bearer token-123'}),
      );

      // HAR과 dio의 대소문자가 다르므로 키는 소문자로 정규화한다.
      expect(
        capture.captured.single.headers.containsKey('authorization'),
        isTrue,
      );
    });

    test('allowlist 밖의 휘발성 헤더는 버린다', () async {
      final capture = RequestCapture();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..interceptors.add(capture)
        ..httpClientAdapter = _StubAdapter();

      await dio.get<dynamic>(
        '/api/v1/ping',
        options: Options(
          headers: {'User-Agent': 'dio/5', 'X-Request-Time': '12345'},
        ),
      );

      expect(
        capture.captured.single.headers.keys,
        everyElement(isIn(kCapturedHeaders)),
      );
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
