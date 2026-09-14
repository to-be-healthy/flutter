import 'package:dio/dio.dart';

import '../model/find_account.dart';
import '../model/sign_in_request.dart';
import '../model/sign_in_response.dart';

class AuthApi {
  AuthApi(this._dio);

  /// 배포 서버 OpenAPI에서 확인한 실제 경로.
  static const String signInPath = '/api/v1/auth/login';

  /// 웹 `feature/auth/api/mutations.ts`의 `useFindIdMutation`.
  ///
  /// 두 find 경로 모두 웹에서 **토큰 없는 `api` 인스턴스**를 쓴다. 앱에서는
  /// `AuthInterceptor._publicPaths`의 `/auth/find/`가 같은 역할을 한다 —
  /// 실제 캡처(`har/find-id.har`)에도 `authorization` 헤더가 없다.
  static const String findIdPath = '/api/v1/auth/find/user-id';
  static const String findPasswordPath = '/api/v1/auth/find/password';

  final Dio _dio;

  Future<SignInResponse> signIn(SignInRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      signInPath,
      data: request.toJson(),
    );
    final body = response.data;
    if (body == null) {
      throw const FormatException('로그인 응답 바디가 비었다');
    }
    return SignInResponse.fromJson(body);
  }

  Future<FindIdResponse> findId(FindAccountRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      findIdPath,
      data: request.toJson(),
    );
    final body = response.data;
    if (body == null) {
      throw const FormatException('아이디 찾기 응답 바디가 비었다');
    }
    return FindIdResponse.fromJson(body);
  }

  Future<FindPasswordResponse> findPassword(FindAccountRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      findPasswordPath,
      data: request.toJson(),
    );
    final body = response.data;
    if (body == null) {
      throw const FormatException('비밀번호 찾기 응답 바디가 비었다');
    }
    return FindPasswordResponse.fromJson(body);
  }
}
