import 'package:dio/dio.dart';

import '../model/gym.dart';

/// 웹 `src/entity/gym/api/*` 대응.
///
/// 두 경로 모두 웹에서 **`authApi`**(토큰 주입)를 쓰고, 앱에서도
/// `AuthInterceptor._publicPaths`에 걸리지 않아 토큰이 붙는다 —
/// 공개 경로는 전부 `/api/v1/auth` 아래이고 `/api/v1/gyms`는 거기 없다.
class GymApi {
  GymApi(this._dio);

  /// `openapi/api-docs.json` 실측 경로.
  static const String gymsPath = '/api/v1/gyms';

  final Dio _dio;

  /// 웹 `useGymListQuery`. `GET /api/v1/gyms` → `ApiResultListGymResult`.
  Future<List<Gym>> list() async {
    final response = await _dio.get<Map<String, dynamic>>(gymsPath);
    return Gym.listFrom(response.data?['data']);
  }

  /// 웹 `useRegisterGymMutation`. `POST /api/v1/gyms/{gymId}`.
  ///
  /// **[joinCode]가 없으면 바디를 보내지 않는다.** 웹이
  /// `payload = memberType === 'TRAINER' ? { joinCode } : undefined`이고,
  /// axios는 `data === undefined`면 `Content-Type`을 붙이지 않는다. 여기서
  /// 빈 맵(`{}`)을 넘기면 dio의 `ImplyContentTypeInterceptor`가
  /// `application/json`을 붙여 **웹이 보내지 않는 헤더가 생긴다** —
  /// 하네스의 `CAPTURED_HEADERS`에 `content-type`이 있어 패리티로 드러난다.
  /// `DioClient.create`가 전역 `contentType`을 지정하지 않는 것이 이 성질의
  /// 전제다.
  Future<void> registerGym({required int gymId, String? joinCode}) async {
    await _dio.post<Map<String, dynamic>>(
      '$gymsPath/$gymId',
      data: joinCode == null ? null : <String, dynamic>{'joinCode': joinCode},
    );
  }
}
