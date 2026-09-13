import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';
import 'package:geonganghaejim/entity/auth/model/sign_in_request.dart';

/// 지정한 바디를 그대로 돌려주는 어댑터.
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

AuthApi _apiWith(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return AuthApi(dio);
}

const SignInRequest _request = SignInRequest(
  userId: 'tester',
  password: 'pw1234',
  memberType: 'STUDENT',
);

void main() {
  group('AuthApi.signIn', () {
    test('정상 envelope를 SignInResponse로 파싱한다', () async {
      final adapter = _StubAdapter('''
{"status":200,"message":"성공","data":{
  "memberId":7,"name":"정선우","accessToken":"at","refreshToken":"rt",
  "userId":"tester","memberType":"STUDENT","gymId":null}}
''');

      final response = await _apiWith(adapter).signIn(_request);

      expect(response.memberId, 7);
      expect(response.accessToken, 'at');
      expect(response.refreshToken, 'rt');
      expect(response.memberType, 'STUDENT');
      expect(response.gymId, isNull);
    });

    test('실측 경로로 POST하고 요청 바디는 toJson 그대로다', () async {
      final adapter = _StubAdapter('''
{"status":200,"message":"성공","data":{
  "memberId":7,"name":"정선우","accessToken":"at","refreshToken":"rt",
  "userId":"tester","memberType":"STUDENT","gymId":null}}
''');

      await _apiWith(adapter).signIn(_request);

      final sent = adapter.lastRequest!;
      expect(sent.method, 'POST');
      expect(sent.path, '/api/v1/auth/login');
      expect(sent.data, _request.toJson());
    });

    test('바디가 비면 진단 가능한 FormatException을 던진다', () async {
      final adapter = _StubAdapter('');

      await expectLater(
        _apiWith(adapter).signIn(_request),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('바디가 비었다'),
          ),
        ),
      );
    });

    test('data가 없는 envelope는 SignInResponse의 진단을 그대로 낸다', () async {
      final adapter = _StubAdapter(
        '{"status":400,"message":"아이디 또는 비밀번호가 틀렸습니다","data":null}',
      );

      await expectLater(
        _apiWith(adapter).signIn(_request),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('아이디 또는 비밀번호가 틀렸습니다'),
          ),
        ),
      );
    });
  });
}
