import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 골든·캡처 양쪽이 보존하는 헤더 **allowlist**. 키는 소문자로 정규화한다
/// (HAR은 `Content-Type`, dio는 `content-type`처럼 표기가 다르다).
///
/// 여기 없는 헤더는 버린다 — `user-agent`·`accept-encoding`·타임스탬프처럼
/// 매 실행 달라지는 값이 골든에 들어가면 모든 화면이 오탐한다.
///
/// **`tool/har_to_golden.py`의 `CAPTURED_HEADERS`와 반드시 같게 유지할 것.**
/// `har_to_golden_test.py`의 drift 가드가 두 집합을 대조한다.
///
/// 알려진 결과 하나: `DioClient`가 `BaseOptions.contentType`을 전역으로
/// 지정하므로 **본문 없는 GET에도 `content-type`이 붙는다**(브라우저는 붙이지
/// 않는다). 첫 골든 대조에서 GET마다 `headers.content-type: 예상치 못한 추가`가
/// 뜨면, 그건 하네스의 오탐이 아니라 실제 차이다 — allowlist를 좁히지 말고
/// `DioClient`를 웹과 맞춰라.
const Set<String> kCapturedHeaders = {'content-type', 'authorization'};

/// 값이 아니라 **존재만** 비교하는 헤더(`kMaskedKeys`와 같은 규칙).
///
/// `authorization`의 값은 계정마다·요청마다 다른 실토큰이라 골든에 평문으로
/// 남아서도, 값으로 대조돼서도 안 된다. 그러나 **헤더가 붙는지 아닌지는**
/// 대조해야 한다 — 토큰을 아예 안 붙이는 화면이 올바른 화면과 구별되지
/// 않으면 62개 화면의 인증 검증이 통째로 빈다.
const Set<String> kPresenceOnlyHeaders = {'authorization'};

/// 패리티 비교 대상이 되는 요청의 최소 표현.
///
/// 헤더는 [kCapturedHeaders] allowlist만 담는다. 나머지(User-Agent·
/// 타임스탬프 등)는 매 실행 달라지므로 의도적으로 버린다.
@immutable
class CapturedRequest {
  const CapturedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
    this.headers = const {},
  });

  factory CapturedRequest.fromJson(Map<String, dynamic> json) {
    return CapturedRequest(
      method: json['method'] as String,
      path: json['path'] as String,
      query: Map<String, dynamic>.from(json['query'] as Map? ?? {}),
      body: json['body'],
      headers: (json['headers'] as Map? ?? {}).map(
        (key, value) => MapEntry('$key'.toLowerCase(), '$value'),
      ),
    );
  }

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Object? body;

  /// 소문자 키로 정규화된 allowlist 헤더.
  final Map<String, String> headers;

  Map<String, dynamic> toJson() => {
    'method': method,
    'path': path,
    'query': query,
    'headers': headers,
    'body': body,
  };
}

/// dio에 끼워 요청을 수집하는 인터셉터. 테스트 전용.
class RequestCapture extends Interceptor {
  final List<CapturedRequest> _captured = [];

  List<CapturedRequest> get captured => List.unmodifiable(_captured);

  void clear() => _captured.clear();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _captured.add(
      CapturedRequest(
        method: options.method.toUpperCase(),
        path: options.path,
        query: Map<String, dynamic>.from(options.queryParameters),
        body: options.data,
        headers: pickCapturedHeaders(options.headers),
      ),
    );
    handler.next(options);
  }
}

/// 헤더 맵에서 [kCapturedHeaders]만 소문자 키로 골라낸다.
///
/// 캡처 시점에 거르는 이유: 걸러지지 않은 `CapturedRequest`가 로그·실패
/// 리포트에 찍히면 실토큰이 CI 로그로 샌다. 기록 자체를 최소로 만든다.
Map<String, String> pickCapturedHeaders(Map<String, dynamic> raw) {
  final picked = <String, String>{};
  raw.forEach((key, value) {
    final lower = key.toLowerCase();
    if (kCapturedHeaders.contains(lower)) {
      picked[lower] = '$value';
    }
  });
  return picked;
}
