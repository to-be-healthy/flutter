import 'package:dio/dio.dart';

import '../model/sign_in_request.dart';
import '../model/sign_in_response.dart';

class AuthApi {
  AuthApi(this._dio);

  /// 배포 서버 OpenAPI에서 확인한 실제 경로.
  static const String signInPath = '/api/v1/auth/login';

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
}
