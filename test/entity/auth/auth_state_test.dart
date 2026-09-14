import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/entity/auth/model/auth_state.dart';
import 'package:geonganghaejim/entity/auth/model/auth_user.dart';
import 'package:geonganghaejim/entity/auth/model/sign_in_response.dart';

import '../../support/auth_fakes.dart';

SignInResponse _response({
  String memberType = 'STUDENT',
  String access = 'access-token',
  String refresh = 'refresh-token',
}) {
  return SignInResponse.fromJson({
    'status': 'success',
    'message': '로그인 성공',
    'data': {
      'memberId': 6,
      'name': '홍길동',
      'accessToken': access,
      'refreshToken': refresh,
      'userId': 'healthy-student0',
      'memberType': memberType,
      'gymId': 1,
    },
  });
}

void main() {
  late FakeTokenStorage tokens;
  late FakeAuthProfileStorage profile;
  late AuthState auth;

  setUp(() {
    tokens = FakeTokenStorage();
    profile = FakeAuthProfileStorage();
    auth = AuthState(tokens, profile);
  });

  group('복원', () {
    test('시작 상태는 복원 중이다', () {
      // 라우터가 이 값을 보고 스플래시를 유지한다. false로 시작하면
      // 로그인 상태인 사용자가 매번 온보딩을 스치고 지나간다.
      expect(auth.isRestoring, isTrue);
      expect(auth.isSignedIn, isFalse);
    });

    test('저장된 것이 없으면 로그아웃 상태로 끝난다', () async {
      await auth.restore();

      expect(auth.isRestoring, isFalse);
      expect(auth.isSignedIn, isFalse);
      expect(tokens.clearCount, 0, reason: '지울 것이 없으면 쓰기도 하지 않는다');
    });

    test('토큰과 프로필이 모두 있으면 로그인 상태로 복원한다', () async {
      tokens = FakeTokenStorage(access: 'a', refresh: 'r');
      profile = FakeAuthProfileStorage(
        user: const AuthUser(
          memberId: 6,
          name: '홍길동',
          userId: 'u',
          memberType: 'TRAINER',
        ),
      );
      auth = AuthState(tokens, profile);

      await auth.restore();

      expect(auth.isSignedIn, isTrue);
      expect(auth.user!.homeLocation, '/trainer');
    });

    test('토큰만 있으면 로그아웃 취급하고 양쪽을 지운다', () async {
      // 인터셉터는 헤더를 붙이는데 라우터는 갈 곳을 모르는 어긋난 상태다.
      tokens = FakeTokenStorage(access: 'a', refresh: 'r');
      auth = AuthState(tokens, profile);

      await auth.restore();

      expect(auth.isSignedIn, isFalse);
      expect(tokens.access, isNull);
      expect(tokens.clearCount, 1);
      expect(profile.clearCount, 1);
    });

    test('프로필만 있으면 로그아웃 취급하고 양쪽을 지운다', () async {
      profile = FakeAuthProfileStorage(
        user: const AuthUser(
          memberId: 6,
          name: '홍길동',
          userId: 'u',
          memberType: 'STUDENT',
        ),
      );
      auth = AuthState(tokens, profile);

      await auth.restore();

      expect(auth.isSignedIn, isFalse);
      expect(profile.user, isNull);
      expect(tokens.clearCount, 1);
    });

    test('복원이 끝나면 청취자에게 알린다', () async {
      // 이 알림이 `go_router`의 `refreshListenable`을 깨워 리다이렉트를
      // 다시 계산한다. 없으면 스플래시에서 멈춘다.
      var notified = 0;
      auth.addListener(() => notified++);

      await auth.restore();

      expect(notified, 1);
    });
  });

  group('로그인·로그아웃', () {
    test('토큰과 프로필을 저장하고 알린다', () async {
      var notified = 0;
      auth.addListener(() => notified++);

      await auth.signIn(_response());

      expect(tokens.access, 'access-token');
      expect(tokens.refresh, 'refresh-token');
      expect(profile.user!.userId, 'healthy-student0');
      expect(auth.isSignedIn, isTrue);
      expect(notified, 1);
    });

    test('memberType은 응답 값을 그대로 담는다', () async {
      // 웹도 `router.replace(`/${data.memberType?.toLowerCase()}`)`로 응답을
      // 쓴다. 요청 값을 믿으면 반대 역할의 홈으로 보내게 된다.
      await auth.signIn(_response(memberType: 'TRAINER'));

      expect(auth.user!.memberType, 'TRAINER');
      expect(auth.user!.homeLocation, '/trainer');
    });

    test('로그아웃하면 토큰과 프로필을 모두 지운다', () async {
      await auth.signIn(_response());

      await auth.signOut();

      expect(auth.isSignedIn, isFalse);
      expect(tokens.access, isNull);
      expect(profile.user, isNull);
      expect(tokens.clearCount, 1);
      expect(profile.clearCount, 1);
    });
  });

  group('로그인 → 인증 요청 (end-to-end)', () {
    test('로그인 뒤의 보호 경로 요청에 Authorization이 붙는다', () async {
      // **하네스에 남아 있던 가장 큰 미검증 주장이다.**
      //
      // 최종 리뷰의 지적: "인증 요청이 헤더 없이 나가도 패리티가 통과한다".
      // 원인은 `TokenStorage.writeTokens`의 프로덕션 호출부가 0개였던 것이고,
      // 인터셉터 테스트는 토큰을 손으로 심어 넣어서 그 구멍을 못 봤다.
      //
      // 여기서는 저장소 **한 개**를 `AuthState`와 `DioClient`가 나눠 쓴다 —
      // 로그인 응답이 실제로 헤더까지 도달하는지가 이 한 줄로 결정된다.
      final capture = _HeaderCapture();
      final dio = DioClient.create(
        baseUrl: 'https://example.test',
        storage: tokens,
      );
      dio.httpClientAdapter = capture;

      await auth.signIn(_response(access: 'fresh-token'));
      await dio.get<void>('/api/v1/home/student');

      expect(capture.lastHeaders['Authorization'], 'Bearer fresh-token');
    });

    test('로그아웃 뒤에는 Authorization이 붙지 않는다', () async {
      final capture = _HeaderCapture();
      final dio = DioClient.create(
        baseUrl: 'https://example.test',
        storage: tokens,
      );
      dio.httpClientAdapter = capture;

      await auth.signIn(_response());
      await auth.signOut();
      await dio.get<void>('/api/v1/home/student');

      expect(capture.lastHeaders.containsKey('Authorization'), isFalse);
    });

    test('로그인해도 로그인 요청 자체에는 Authorization이 붙지 않는다', () async {
      // 웹도 토큰 없는 `api` 인스턴스로 보낸다(`mutations.ts`).
      // 재로그인 시 옛 토큰이 실려 나가면 골든과 어긋난다.
      final capture = _HeaderCapture();
      final dio = DioClient.create(
        baseUrl: 'https://example.test',
        storage: tokens,
      );
      dio.httpClientAdapter = capture;

      await auth.signIn(_response());
      await dio.post<void>('/api/v1/auth/login', data: <String, String>{});

      expect(capture.lastHeaders.containsKey('Authorization'), isFalse);
    });
  });

  group('AuthUser 직렬화', () {
    test('왕복해도 같다', () {
      const user = AuthUser(
        memberId: 6,
        name: '홍길동',
        userId: 'u',
        memberType: 'STUDENT',
        gymId: 1,
      );

      expect(AuthUser.decode(AuthUser.encode(user)), user);
    });

    test('gymId가 없어도 왕복한다', () {
      // 헬스장 미선택 상태(`Tokens.gymId`가 null)다.
      const user = AuthUser(
        memberId: 6,
        name: '홍길동',
        userId: 'u',
        memberType: 'STUDENT',
      );

      final restored = AuthUser.decode(AuthUser.encode(user));

      expect(restored, user);
      expect(restored!.gymId, isNull);
    });

    test('깨진 값은 null로 돌려주고 던지지 않는다', () {
      // 앱 버전이 올라가 필드가 바뀌었을 때 **기동 자체가 막히면 안 된다.**
      // 복원에 실패하면 로그아웃으로 떨어지는 것이 정답이다.
      expect(AuthUser.decode(null), isNull);
      expect(AuthUser.decode(''), isNull);
      expect(AuthUser.decode('not json'), isNull);
      expect(AuthUser.decode('[]'), isNull);
      expect(AuthUser.decode('{"memberId":1}'), isNull);
    });
  });
}

/// 요청 헤더만 들여다보고 빈 200을 돌려주는 어댑터.
class _HeaderCapture implements HttpClientAdapter {
  Map<String, dynamic> lastHeaders = <String, dynamic>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastHeaders = Map<String, dynamic>.from(options.headers);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
