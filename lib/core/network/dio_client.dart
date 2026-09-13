import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// 앱이 쓰는 `Dio` 인스턴스를 조립한다.
///
/// [baseUrl]에는 **오리진만** 넣는다(`https://geonganghaejim.site`).
/// `/api/v1` 같은 경로 접두사를 baseUrl로 옮기면 패리티 하네스가 캡처하는
/// `RequestOptions.path`가 HAR 골든의 전체 경로와 어긋난다.
abstract final class DioClient {
  static Dio create({
    required String baseUrl,
    TokenStorage? storage,
    List<Interceptor> extra = const <Interceptor>[],
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        contentType: Headers.jsonContentType,
      ),
    );

    if (storage != null) {
      dio.interceptors.add(AuthInterceptor(storage: storage));
    }
    dio.interceptors.addAll(extra);

    return dio;
  }
}
