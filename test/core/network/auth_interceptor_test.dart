import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/auth_interceptor.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/storage/token_storage.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';

/// 테스트가 끼워 넣는 토큰 저장소.
///
/// `TokenStorage`를 인터페이스로 둔 이유가 이것이다 — OS 보안 저장소는
/// 테스트 바이너리에서 쓸 수 없다.
class _FakeStorage implements TokenStorage {
  _FakeStorage({this.access});

  String? access;
  String? refresh;
  int readAccessCount = 0;

  @override
  Future<String?> readAccess() async {
    readAccessCount++;
    return access;
  }

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> writeTokens({
    required String access,
    required String refresh,
  }) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

/// 소켓을 열지 않고 인터셉터 체인을 **통과한 뒤의** 요청을 붙잡는 어댑터.
///
/// 인터셉터를 직접 호출하는 대신 실제 dio 파이프라인을 태우는 이유는
/// 브리프의 `RequestInterceptorHandler()..next(options)` 패턴이 핸들러의
/// `Completer`를 미리 완료시켜, 구현이 `handler.next()`를 부르는 순간
/// `StateError`가 나기 때문이다(dio 5.11.1 `_BaseHandler._throwIfCompleted`).
/// `extra`로 넘긴 인터셉터가 실제로 체인에 들어갔는지 세는 용도.
class _CountingInterceptor extends Interceptor {
  int count = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    count++;
    handler.next(options);
  }
}

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      '{"status":200,"message":"ok","data":null}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// [path]로 GET을 보내고 어댑터가 실제로 받아든 최종 요청을 돌려준다.
///
/// 인터셉터를 손으로 끼우지 않고 **운영과 같은 `DioClient.create`로 조립**한다.
/// 그래야 아래 단언들이 인터셉터 로직뿐 아니라 팩토리의 배선까지 함께 덮는다.
Future<RequestOptions> _sendThrough(
  TokenStorage storage,
  String path, {
  List<Interceptor> extra = const <Interceptor>[],
}) async {
  final adapter = _CapturingAdapter();
  final dio = DioClient.create(
    baseUrl: 'https://example.test',
    storage: storage,
    extra: extra,
  )..httpClientAdapter = adapter;

  await dio.get<dynamic>(path);

  final captured = adapter.lastRequest;
  expect(captured, isNotNull, reason: '인터셉터가 요청을 흘려보내지 않았다');
  return captured!;
}

void main() {
  group('AuthInterceptor', () {
    test('액세스 토큰이 있으면 Authorization 헤더를 붙인다', () async {
      final storage = _FakeStorage(access: 'token-abc');

      final request = await _sendThrough(storage, '/api/v1/members/me');

      expect(request.headers['Authorization'], 'Bearer token-abc');
    });

    test('토큰이 없으면 Authorization 헤더를 붙이지 않는다', () async {
      final storage = _FakeStorage();

      final request = await _sendThrough(storage, '/api/v1/members/me');

      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('빈 문자열 토큰은 붙이지 않는다', () async {
      final storage = _FakeStorage(access: '');

      final request = await _sendThrough(storage, '/api/v1/members/me');

      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('로그인 요청에는 Authorization을 붙이지 않는다', () async {
      final storage = _FakeStorage(access: 'token-abc');

      final request = await _sendThrough(storage, AuthApi.signInPath);

      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('공개 경로는 저장소를 읽지도 않는다', () async {
      final storage = _FakeStorage(access: 'token-abc');

      await _sendThrough(storage, AuthApi.signInPath);

      expect(storage.readAccessCount, 0);
    });

    test('백엔드의 공개 인증 경로 전부에 토큰을 붙이지 않는다', () async {
      // 실측: MemberAuthController / MemberAuthCommandController의
      // `@RequestMapping("/api/v1/auth")` 하위 경로.
      for (final path in const <String>[
        '/api/v1/auth/login',
        '/api/v1/auth/join',
        '/api/v1/auth/refresh-token',
        '/api/v1/auth/find/user-id',
        '/api/v1/auth/find/password',
      ]) {
        final storage = _FakeStorage(access: 'token-abc');

        final request = await _sendThrough(storage, path);

        expect(
          request.headers.containsKey('Authorization'),
          isFalse,
          reason: path,
        );
      }
    });

    test('보호 경로에는 토큰을 붙인다 — logout은 login에 걸리지 않는다', () async {
      for (final path in const <String>[
        '/api/v1/members/me',
        '/api/v1/members/logout',
        '/api/v1/schedule/student',
        '/api/v1/workout-histories',
        '/api/v1/gyms',
        // 가상의 경로. `_publicPaths`가 앵커링 없는 'login'으로
        // 퇴화하면 이 경로가 공개로 오판돼 이 케이스가 깨진다.
        '/api/v1/members/login-history',
      ]) {
        final storage = _FakeStorage(access: 'token-abc');

        final request = await _sendThrough(storage, path);

        expect(
          request.headers['Authorization'],
          'Bearer token-abc',
          reason: path,
        );
      }
    });
  });

  group('DioClient.create 조립', () {
    // 웹(브라우저/axios)은 본문 없는 요청에 Content-Type을 붙이지 않는다.
    // HTTP 의미론상으로도 본문 없는 요청의 Content-Type은 무엇의 타입인지
    // 지시할 대상이 없어 무의미하다. 패리티 골든은 웹 HAR에서 오므로, 여기서
    // 어긋나면 **62개 화면의 모든 GET이 패리티 실패**한다.
    //
    // 비교를 느슨하게 해서 덮지 말고 요청 자체를 웹과 맞춘다 —
    // `test/harness/request_capture.dart`의 allowlist 주석도 같은 취지다.
    test('본문 없는 GET에는 content-type을 붙이지 않는다 (웹과 동일)', () async {
      final adapter = _CapturingAdapter();
      final dio = DioClient.create(baseUrl: 'https://example.test')
        ..httpClientAdapter = adapter;

      await dio.get<dynamic>('/api/v1/members/me');

      final headers = adapter.lastRequest!.headers;
      expect(
        headers.keys.map((k) => k.toLowerCase()),
        isNot(contains(Headers.contentTypeHeader)),
        reason: '본문 없는 GET에 content-type이 붙으면 모든 GET 골든이 어긋난다',
      );
    });

    test('본문 있는 POST에는 application/json을 붙인다', () async {
      // GET에서 빼는 것이 "JSON을 안 쓴다"는 뜻이 되면 안 된다. dio의
      // ImplyContentTypeInterceptor가 data가 있을 때만 추론해 붙인다.
      final adapter = _CapturingAdapter();
      final dio = DioClient.create(baseUrl: 'https://example.test')
        ..httpClientAdapter = adapter;

      await dio.post<dynamic>(
        AuthApi.signInPath,
        data: <String, dynamic>{'userId': 'testuser'},
      );

      expect(
        adapter.lastRequest!.headers[Headers.contentTypeHeader],
        Headers.jsonContentType,
      );
    });

    test('extra 인터셉터도 체인에 들어간다', () async {
      final counter = _CountingInterceptor();

      await _sendThrough(
        _FakeStorage(access: 'token-abc'),
        '/api/v1/members/me',
        extra: <Interceptor>[counter],
      );

      expect(counter.count, 1);
    });

    test('storage가 null이면 AuthInterceptor를 달지 않는다', () async {
      final adapter = _CapturingAdapter();
      final dio = DioClient.create(baseUrl: 'https://example.test')
        ..httpClientAdapter = adapter;

      await dio.get<dynamic>('/api/v1/members/me');

      expect(
        dio.interceptors.whereType<AuthInterceptor>(),
        isEmpty,
        reason: 'storage 없이 만든 dio에 인증 인터셉터가 붙었다',
      );
      expect(
        adapter.lastRequest!.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('baseUrl은 오리진만 담고 경로 접두사를 삼키지 않는다', () async {
      final request = await _sendThrough(
        _FakeStorage(access: 'token-abc'),
        '/api/v1/members/me',
      );

      // 패리티 하네스가 캡처하는 path가 HAR 골든의 전체 경로와 일치해야 한다.
      expect(request.path, '/api/v1/members/me');
      expect(request.baseUrl, 'https://example.test');
    });
  });
}
