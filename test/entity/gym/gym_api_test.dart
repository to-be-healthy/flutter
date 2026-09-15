import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/entity/gym/api/gym_api.dart';

import '../../harness/request_capture.dart';

/// 지정한 바디를 그대로 돌려주는 어댑터. `auth_api_test.dart`와 같은 형태다.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GymApi _apiWith(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return GymApi(dio);
}

void main() {
  group('GymApi.list', () {
    test('정상 envelope를 Gym 목록으로 파싱한다', () async {
      final adapter = _StubAdapter('''
{"status":200,"message":"성공","data":[
  {"gymId":1,"name":"건강해짐 강남점"},
  {"gymId":2,"name":"건강해짐 판교점"}]}
''');

      final gyms = await _apiWith(adapter).list();

      expect(gyms, hasLength(2));
      expect(gyms.first.gymId, 1);
      expect(gyms.first.name, '건강해짐 강남점');
      expect(gyms.last.gymId, 2);
    });

    // 웹 `useGymListQuery`의 반환 타입이 `Gym[] | null`이다 — 서버가 data에
    // null을 줄 수 있다는 뜻이고, 그대로 두면 화면이 null을 map하려다 죽는다.
    test('data가 null이면 빈 목록이다', () async {
      final adapter = _StubAdapter('{"status":200,"message":"성공","data":null}');

      final gyms = await _apiWith(adapter).list();

      expect(gyms, isEmpty);
    });

    test('data 키 자체가 없어도 빈 목록이다', () async {
      final adapter = _StubAdapter('{"status":200,"message":"성공"}');

      final gyms = await _apiWith(adapter).list();

      expect(gyms, isEmpty);
    });

    test('OpenAPI 실측 경로로 GET한다', () async {
      final adapter = _StubAdapter('{"status":200,"message":"성공","data":[]}');

      await _apiWith(adapter).list();

      final sent = adapter.lastRequest!;
      expect(sent.method, 'GET');
      expect(sent.path, '/api/v1/gyms');
    });
  });

  group('GymApi.registerGym', () {
    // 웹 `mutations.ts`: `payload = memberType === 'TRAINER' ? { joinCode } : undefined`.
    // STUDENT 경로에서 빈 맵(`{}`)을 보내면 웹이 보내지 않는 본문을 보내는 것이다.
    test('joinCode가 없으면 바디 없이 POST한다', () async {
      final adapter = _StubAdapter(
        '{"status":200,"message":"성공","data":{"id":3,"name":"건강해짐 강남점"}}',
      );

      await _apiWith(adapter).registerGym(gymId: 3);

      final sent = adapter.lastRequest!;
      expect(sent.method, 'POST');
      expect(sent.path, '/api/v1/gyms/3');
      expect(sent.data, isNull);
    });

    test('joinCode가 있으면 {joinCode}만 담아 POST한다', () async {
      final adapter = _StubAdapter(
        '{"status":200,"message":"성공","data":{"id":3,"name":"건강해짐 강남점"}}',
      );

      await _apiWith(adapter).registerGym(gymId: 3, joinCode: '123456');

      final sent = adapter.lastRequest!;
      expect(sent.method, 'POST');
      expect(sent.path, '/api/v1/gyms/3');
      expect(sent.data, <String, dynamic>{'joinCode': '123456'});
    });

    test('gymId가 경로에 들어간다', () async {
      final adapter = _StubAdapter(
        '{"status":200,"message":"성공","data":{"id":42,"name":"건강해짐 판교점"}}',
      );

      await _apiWith(adapter).registerGym(gymId: 42);

      expect(adapter.lastRequest!.path, '/api/v1/gyms/42');
    });
  });

  // 위 그룹은 맨 dio 위에서 `data`만 본다. 여기서는 **앱이 실제로 조립하는**
  // `DioClient.create` 위에서 헤더까지 본다 — 패리티 골든이 대조하는 것이
  // 이쪽이기 때문이다.
  group('DioClient 조립 위에서의 등록 요청 헤더', () {
    late RequestCapture capture;
    late GymApi api;

    setUp(() {
      capture = RequestCapture();
      final dio = DioClient.create(
        baseUrl: 'https://example.test',
        extra: <Interceptor>[capture],
      );
      dio.httpClientAdapter = _StubAdapter(
        '{"status":200,"message":"성공","data":{"id":3,"name":"건강해짐 강남점"}}',
      );
      api = GymApi(dio);
    });

    // 웹 axios는 `data === undefined`면 Content-Type을 붙이지 않는다.
    // `registerGym`이 빈 맵을 넘기는 순간 dio의 `ImplyContentTypeInterceptor`가
    // `application/json`을 붙여 웹에 없는 헤더가 생긴다.
    test('STUDENT 경로(바디 없음)에는 content-type이 붙지 않는다', () async {
      await api.registerGym(gymId: 3);

      expect(capture.captured.single.headers, isNot(contains('content-type')));
    });

    test('TRAINER 경로(joinCode)에는 application/json이 붙는다', () async {
      await api.registerGym(gymId: 3, joinCode: '123456');

      expect(
        capture.captured.single.headers['content-type'],
        startsWith('application/json'),
      );
    });
  });
}
