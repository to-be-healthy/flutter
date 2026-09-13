import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 패리티 비교 대상이 되는 요청의 최소 표현.
///
/// Authorization 헤더·타임스탬프·User-Agent는 매 실행 달라지므로
/// 의도적으로 제외한다. 비교 대상은 "어떤 엔드포인트에 무엇을 보내는가"다.
@immutable
class CapturedRequest {
  const CapturedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
  });

  factory CapturedRequest.fromJson(Map<String, dynamic> json) {
    return CapturedRequest(
      method: json['method'] as String,
      path: json['path'] as String,
      query: Map<String, dynamic>.from(json['query'] as Map? ?? {}),
      body: json['body'],
    );
  }

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Object? body;

  Map<String, dynamic> toJson() => {
    'method': method,
    'path': path,
    'query': query,
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
      ),
    );
    handler.next(options);
  }
}
