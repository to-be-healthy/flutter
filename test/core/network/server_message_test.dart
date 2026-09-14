import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/server_message.dart';

DioException _error(Object? data, {int statusCode = 400}) {
  final options = RequestOptions(path: '/api/v1/auth/find/user-id');
  return DioException(
    requestOptions: options,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
    ),
  );
}

void main() {
  group('serverMessage', () {
    test('실패 envelope의 message를 꺼낸다', () {
      // 실측 응답: 존재하지 않는 회원으로 아이디 찾기를 부르면
      // HTTP 404 + `{"message":"회원이 존재하지 않습니다.","code":"400"}`.
      expect(
        serverMessage(
          _error(<String, dynamic>{
            'message': '회원이 존재하지 않습니다.',
            'code': '400',
          }, statusCode: 404),
        ),
        '회원이 존재하지 않습니다.',
      );
    });

    test('상태 코드로 분기하지 않는다', () {
      // 서버가 HTTP 404를 주면서 본문 `code`는 "400"이라고 말한다(실측).
      // 둘 중 무엇을 믿느냐로 동작이 갈리므로 아예 보지 않는다 — 웹도 같다.
      for (final status in <int>[400, 401, 404, 500]) {
        expect(
          serverMessage(
            _error(<String, dynamic>{'message': '같은 문구'}, statusCode: status),
          ),
          '같은 문구',
          reason: 'status=$status',
        );
      }
    });

    test('빈 message는 null로 돌려준다 — 호출부의 기본 문구로 떨어진다', () {
      // **승격하면서 바뀐 동작이다.** 원래 두 화면의 private 헬퍼는 `''`를
      // 그대로 돌려줬고, 로그인 화면은 그걸로 **빈 에러 Text**를 그렸다
      // (문구는 없는데 위아래 s6 간격만 생긴다). 토스트도 빈 검은 막대가
      // 된다. null로 떨어뜨려 호출부의 '문제가 발생했습니다.'를 쓰게 한다.
      expect(serverMessage(_error(<String, dynamic>{'message': ''})), isNull);
    });

    test('message가 없거나 문자열이 아니면 null이다', () {
      expect(serverMessage(_error(<String, dynamic>{'code': '400'})), isNull);
      expect(serverMessage(_error(<String, dynamic>{'message': 42})), isNull);
    });

    test('본문이 Map이 아니면 null이다', () {
      // 게이트웨이가 HTML 오류 페이지를 돌려주는 경우가 여기다.
      expect(serverMessage(_error('<html>502 Bad Gateway</html>')), isNull);
      expect(serverMessage(_error(null)), isNull);
    });

    test('DioException이 아니면 null이다', () {
      // 응답 파싱 실패(`FormatException`) 등 — 서버가 준 문구가 애초에 없다.
      expect(serverMessage(const FormatException('바디가 비었다')), isNull);
      expect(serverMessage(StateError('아무거나')), isNull);
    });

    test('응답 자체가 없으면 null이다', () {
      // 네트워크 단절·타임아웃. `response`가 null이다.
      expect(
        serverMessage(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        isNull,
      );
    });
  });
}
