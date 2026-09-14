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
    // `contentType`을 전역으로 지정하지 않는다.
    //
    // `BaseOptions.contentType`은 헤더 맵에 그대로 들어가므로 **본문 없는
    // GET에도 content-type이 붙는다.** 브라우저와 axios는 붙이지 않고,
    // HTTP 의미론상으로도 본문 없는 요청의 Content-Type은 무엇의 타입인지
    // 지시할 대상이 없어 무의미하다. 패리티 골든은 웹 HAR에서 오므로 이
    // 차이는 62개 화면의 모든 GET에서 불일치로 드러난다.
    //
    // 지정하지 않으면 dio의 `ImplyContentTypeInterceptor`가 **`data`가 있을
    // 때만** 타입을 추론해 붙인다(Map/List → `application/json`). 즉 POST는
    // 그대로 JSON이고 GET만 웹과 같아진다 —
    // `auth_interceptor_test.dart`의 `DioClient.create 조립`이 양쪽을 고정한다.
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    if (storage != null) {
      dio.interceptors.add(AuthInterceptor(storage: storage));
    }
    dio.interceptors.addAll(extra);

    return dio;
  }
}
