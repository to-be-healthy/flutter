## Task 5: 백엔드 OpenAPI 스냅샷 + 로그인 DTO

백엔드는 `springdoc-openapi-starter-webmvc-ui:2.8.6`을 쓰므로 런타임에 `/v3/api-docs`로 스펙을 노출한다. **Phase 0에서는 코드 생성기를 도입하지 않는다** — 로그인 하나에 생성기 전체 설정은 과하다. 스냅샷을 확보해 DTO를 스펙과 대조하는 테스트만 두고, 생성기 도입은 Phase 1에서 DTO 수가 늘어난 뒤 평가한다.

**Files:**
- Create: `flutter/openapi/api-docs.json`
- Create: `flutter/lib/entity/auth/model/sign_in_request.dart`
- Create: `flutter/lib/entity/auth/model/sign_in_response.dart`
- Test: `flutter/test/entity/auth/sign_in_dto_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `SignInRequest({required String userId, required String password, required String memberType, bool? complimentaryLogin})` — `toJson()`
  - `SignInResponse.fromJson(Map<String, dynamic>)` — **envelope `{status, message, data}`를 벗겨** `data`에서 `int memberId, String name, String accessToken, String refreshToken, String userId, String memberType, int? gymId`를 읽는다

- [ ] **Step 1: 배포 서버에서 OpenAPI 스냅샷 저장**

배포 서버가 `/v3/api-docs`를 인증 없이 노출한다(ingress가 backend:8080으로 라우팅). **백엔드를 로컬에서 띄우지 않는다** — `.env`의 `DB_URL`이 원격 DB(`원격 DB 주소(`backend/.env` 참고)`)를 가리켜 로컬 기동이 운영 데이터에 붙을 위험이 있고, 스펙은 읽기 전용 GET으로 충분히 얻을 수 있다.

```bash
cd /Users/seonwoo_jung/workspace/personal/tobehealthy/flutter
mkdir -p openapi
curl -sf -m 30 https://geonganghaejim.site/v3/api-docs \
  | python3 -m json.tool > openapi/api-docs.json
python3 -c "import json;d=json.load(open('openapi/api-docs.json'));print(len(d['paths']),'paths')"
```

Expected: `108 paths` 내외. 실패하면(네트워크 차단 등) 중단하고 보고한다 — 스펙 없이 DTO를 추측해서 만들지 않는다.

**컨트롤러가 이미 이 스펙을 조회해 로그인 계약을 확인했다. 아래 Step 3·4의 DTO는 추측이 아니라 실제 스펙에서 온 값이다.**

- [ ] **Step 2: 로그인 엔드포인트 스펙 확인**

```bash
cd /Users/seonwoo_jung/workspace/personal/tobehealthy/flutter
python3 - << 'EOF'
import json
spec = json.load(open('openapi/api-docs.json'))
for path, ops in spec['paths'].items():
    if 'login' in path.lower() or 'signin' in path.lower():
        for method, op in ops.items():
            print(f'{method.upper()} {path}')
            print('  summary:', op.get('summary'))
            rb = op.get('requestBody', {})
            for ct, media in rb.get('content', {}).items():
                print('  request schema:', media.get('schema'))
            for code, resp in op.get('responses', {}).items():
                for ct, media in resp.get('content', {}).items():
                    print(f'  {code} schema:', media.get('schema'))
EOF
```

Expected (컨트롤러가 이미 조회해 확인한 값):

```
POST /api/v1/auth/login  —  로그인
  request CommandLoginMember: userId(string) / password(string) / memberType(enum STUDENT|TRAINER, 필수) / complimentaryLogin(boolean)
  200 → ApiResultTokens: {status, message, data}
     data(Tokens): memberId(int) / name(string) / accessToken(string) / refreshToken(string) / userId(string) / memberType(string) / gymId(int)
```

출력이 위와 다르면 **스펙이 정답이다.** 그 경우 아래 Step 3·4를 스펙에 맞춰 고치고, 무엇이 달랐는지 리포트에 적어라.

- [ ] **Step 3: 실패하는 DTO 테스트 작성**

`test/entity/auth/sign_in_dto_test.dart`:

```dart
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
    final envelope = {
      'status': 'success',
      'message': '로그인 성공',
      'data': {
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
        () => SignInResponse.fromJson({'status': 'fail', 'message': '실패'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('gymId는 없을 수 있다', () {
      final noGym = Map<String, dynamic>.from(envelope);
      noGym['data'] = Map<String, dynamic>.from(envelope['data']! as Map)
        ..remove('gymId');
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
```

- [ ] **Step 4: 테스트 실패 확인 후 DTO 구현**

```bash
flutter test test/entity/auth/sign_in_dto_test.dart
```
Expected: FAIL — URI 없음

`lib/entity/auth/model/sign_in_request.dart`:

```dart
import 'package:flutter/foundation.dart';

/// 백엔드 `CommandLoginMember` 대응.
///
/// 웹은 이메일이 아니라 **아이디(`userId`)**로 로그인하며,
/// `memberType`(STUDENT/TRAINER)이 필수다 — 웹은 이 값을
/// `/sign-in?type=student` 쿼리파라미터로 받아 넘긴다.
@immutable
class SignInRequest {
  const SignInRequest({
    required this.userId,
    required this.password,
    required this.memberType,
    this.complimentaryLogin,
  });

  final String userId;
  final String password;

  /// 'STUDENT' | 'TRAINER'
  final String memberType;

  /// 체험하기 로그인. 지정하지 않으면 전송하지 않는다.
  final bool? complimentaryLogin;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'password': password,
        'memberType': memberType,
        if (complimentaryLogin != null)
          'complimentaryLogin': complimentaryLogin,
      };
}
```

`lib/entity/auth/model/sign_in_response.dart`:

```dart
import 'package:flutter/foundation.dart';

/// 백엔드 `ApiResultTokens` → `data(Tokens)` 대응.
///
/// 응답은 `{status, message, data}` envelope로 감싸여 있다.
/// 웹 zustand `auth-storage`가 보관하던 필드와 같은 집합이다.
@immutable
class SignInResponse {
  const SignInResponse({
    required this.memberId,
    required this.name,
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.memberType,
    this.gymId,
  });

  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw FormatException(
        '로그인 응답에 data가 없다: ${json['status']} ${json['message']}',
      );
    }
    return SignInResponse(
      memberId: data['memberId'] as int,
      name: data['name'] as String,
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: data['userId'] as String,
      memberType: data['memberType'] as String,
      gymId: data['gymId'] as int?,
    );
  }

  final int memberId;
  final String name;
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String memberType;

  /// 헬스장 미선택 상태면 null일 수 있다.
  final int? gymId;
}
```

**스펙과 필드명이 다르면 스펙을 따라 이 파일과 테스트를 함께 수정한다.** 테스트를 통과시키려고 스펙 해석을 바꾸지 않는다.

- [ ] **Step 5: 전체 검증 후 커밋**

```bash
./tool/verify.sh
git add openapi lib/entity test/entity
git commit -m "feat(auth): 백엔드 OpenAPI 스냅샷 확보 및 로그인 DTO 정의"
```

---

