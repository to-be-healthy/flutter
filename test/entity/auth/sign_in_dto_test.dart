import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/entity/auth/model/sign_in_request.dart';
import 'package:geonganghaejim/entity/auth/model/sign_in_response.dart';

void main() {
  group('SignInRequest', () {
    test('toJson이 백엔드 CommandLoginMember 키를 낸다', () {
      const req = SignInRequest(
        userId: 'testuser',
        password: 'pw1234',
        memberType: 'STUDENT',
      );
      expect(req.toJson(), {
        'userId': 'testuser',
        'password': 'pw1234',
        'memberType': 'STUDENT',
      });
    });

    test('complimentaryLogin은 지정했을 때만 포함된다', () {
      const req = SignInRequest(
        userId: 'testuser',
        password: 'pw1234',
        memberType: 'STUDENT',
        complimentaryLogin: true,
      );
      expect(req.toJson()['complimentaryLogin'], isTrue);
    });
  });

  group('SignInResponse', () {
    // 백엔드는 ApiResultTokens envelope로 감싼다: {status, message, data}
    // status는 스펙상 HTTP 상태 문자열 enum이다('200 OK', '401 UNAUTHORIZED' 등).
    final envelope = <String, dynamic>{
      'status': '200 OK',
      'message': '로그인 성공',
      'data': <String, dynamic>{
        'memberId': 42,
        'name': '홍길동',
        'accessToken': 'at',
        'refreshToken': 'rt',
        'userId': 'testuser',
        'memberType': 'STUDENT',
        'gymId': 7,
      },
    };

    test('envelope를 벗겨 data의 토큰을 읽는다', () {
      final res = SignInResponse.fromJson(envelope);
      expect(res.accessToken, 'at');
      expect(res.refreshToken, 'rt');
      expect(res.memberType, 'STUDENT');
      expect(res.memberId, 42);
      expect(res.userId, 'testuser');
      expect(res.name, '홍길동');
      expect(res.gymId, 7);
    });

    test('data가 없으면 명확한 오류를 낸다', () {
      expect(
        () => SignInResponse.fromJson(<String, dynamic>{
          'status': '401 UNAUTHORIZED',
          'message': '아이디 또는 비밀번호가 일치하지 않습니다.',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('401 UNAUTHORIZED'),
              contains('아이디 또는 비밀번호가 일치하지 않습니다.'),
            ),
          ),
        ),
      );
    });

    test('gymId는 없을 수 있다', () {
      final noGym = Map<String, dynamic>.from(envelope);
      noGym['data'] = Map<String, dynamic>.from(
        envelope['data'] as Map<String, dynamic>,
      )..remove('gymId');
      expect(SignInResponse.fromJson(noGym).gymId, isNull);
    });
  });

  group('OpenAPI 스펙 대조', () {
    test('스냅샷에 로그인 엔드포인트가 존재한다', () {
      final file = File('openapi/api-docs.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Task 5 Step 1에서 스냅샷을 먼저 받아야 한다',
      );

      final spec = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final paths = (spec['paths'] as Map).keys.cast<String>();

      expect(
        paths.any((p) => p.toLowerCase().contains('login')),
        isTrue,
        reason: '로그인 경로가 스펙에 없다. Step 2 출력으로 경로를 재확인하라',
      );
    });
  });
}
