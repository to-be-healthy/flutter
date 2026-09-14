import 'package:dio/dio.dart';

/// 백엔드 실패 응답의 `message`를 꺼낸다.
///
/// 백엔드 응답은 성공·실패 모두 `{status, message, data}` envelope라 실패
/// 시에도 사람이 읽을 문구가 온다. 웹은 화면마다
/// `error.response?.data.message`로 같은 값을 꺼내 쓴다
/// (`SignInForm.tsx`, `ComplimentaryButton.tsx`, `FindIdPage.tsx`,
/// `FindPasswordPage.tsx`).
///
/// **원래 `sign_in_page.dart`에 있던 private 헬퍼다.** 거기 주석에
/// "사용처가 두 곳인 지금은 이르다 — 세 번째가 생기면 올린다"고 적어 뒀고,
/// 아이디·비밀번호 찾기가 3·4번째 사용처라 약속대로 올렸다.
///
/// 실패 응답의 상태 코드와 본문 `code`가 어긋나는 경우가 있다 — 실측:
/// 존재하지 않는 회원으로 아이디 찾기를 호출하면 HTTP 404인데 본문은
/// `{"message":"회원이 존재하지 않습니다.","code":"400"}`다. 그래서 상태
/// 코드로 분기하지 않고 `message`만 읽는다(웹도 같다).
String? serverMessage(Object error) {
  if (error is! DioException) {
    return null;
  }
  final data = error.response?.data;
  if (data is! Map) {
    return null;
  }
  final message = data['message'];
  return message is String && message.isNotEmpty ? message : null;
}
