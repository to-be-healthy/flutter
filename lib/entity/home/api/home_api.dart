import 'package:dio/dio.dart';

import '../model/student_home.dart';
import '../model/trainer_home.dart';

/// 웹 `feature/home/api/queries.ts`의 `useStudentHomeDataQuery`.
///
/// 웹은 `authApi`(토큰 주입)를 쓰고, 앱에서도 `AuthInterceptor._publicPaths`에
/// 걸리지 않아 토큰이 붙는다 — 공개 경로는 전부 `/api/v1/auth` 아래다.
class HomeApi {
  HomeApi(this._dio);

  /// `openapi/api-docs.json` 실측 경로. 백엔드 `HomeController`의
  /// `@GetMapping("/student")`이고 `@PreAuthorize("hasAuthority('ROLE_STUDENT')")`
  /// 가 걸려 있다 — 트레이너 토큰으로 부르면 403이다.
  static const String studentHomePath = '/api/v1/home/student';

  /// 백엔드 `HomeController`의 `@GetMapping("/trainer")`.
  static const String trainerHomePath = '/api/v1/home/trainer';

  final Dio _dio;

  Future<StudentHome> studentHome() async {
    final response = await _dio.get<Map<String, dynamic>>(studentHomePath);
    return StudentHome.fromJson(response.data?['data']);
  }

  /// 웹 `useTrainerHomeQuery`. `@PreAuthorize("hasAuthority('ROLE_TRAINER')")`
  /// 가 걸려 있어 회원 토큰으로 부르면 403이다.
  Future<TrainerHome> trainerHome() async {
    final response = await _dio.get<Map<String, dynamic>>(trainerHomePath);
    return TrainerHome.fromJson(response.data?['data']);
  }
}
