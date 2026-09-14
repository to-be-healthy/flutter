# Task 6 보고서 — dio 클라이언트 + 토큰 저장소

**Status:** DONE_WITH_CONCERNS
**Commit:** `081fae9` feat(network): dio 클라이언트·보안 토큰 저장소·인증 인터셉터 추가
**브랜치:** `feature/flutter-phase0` (변경 없음)

---

## 1. 구현한 것

| 파일 | 역할 |
|------|------|
| `lib/core/storage/token_storage.dart` | `TokenStorage` 인터페이스 + `SecureTokenStorage` 구현 |
| `lib/core/network/auth_interceptor.dart` | `AuthInterceptor` — 토큰 부착만 |
| `lib/core/network/dio_client.dart` | `DioClient.create(...)` — dio 조립 |
| `lib/entity/auth/api/auth_api.dart` | `AuthApi.signIn(SignInRequest)` |
| `test/core/network/auth_interceptor_test.dart` | 인터셉터 동작 검증 7 케이스 |
| `pubspec.yaml` / `pubspec.lock` | 의존성 5종 |

의존성: `flutter_secure_storage ^11.1.1`, `flutter_riverpod ^3.4.3`, `go_router ^18.0.1`,
`mocktail ^1.0.5`(dev). `dio`는 Task 4에서 이미 있던 `^5.11.1`이 그대로 유지됐다.

계획의 파일 분리를 그대로 지켰다 — 합치지 않았다.

---

## 2. TDD 증거

### RED

```
$ flutter test test/core/network/auth_interceptor_test.dart
test/core/network/auth_interceptor_test.dart:13:31: Error: Type 'TokenStorage' not found.
test/core/network/auth_interceptor_test.dart:81:24: Error: Method not found: 'AuthInterceptor'.
test/core/network/auth_interceptor_test.dart:119:51: Error: Undefined name 'AuthApi'.
00:00 +0 -1: Some tests failed.
```

이유: `lib/core/storage/`, `lib/core/network/`, `lib/entity/auth/api/`가 아직 없어 컴파일 자체가 실패.

### GREEN

```
$ flutter test test/core/network/auth_interceptor_test.dart
00:00 +7: All tests passed!
```

### 변이(mutation) 검증 — "테스트가 진짜로 동작을 검증하는가"

컴파일 실패만으로는 "테스트가 로직을 검증한다"는 증거가 되지 않으므로, 구현 후
두 가지 변이를 넣어 테스트가 죽는지 확인했다. (원복은 `git checkout` 대신 **유일
문자열 역치환**으로 했다 — 같은 파일의 커밋 전 구현까지 HEAD로 되돌아가는 사고 방지.)

**변이 A — 토큰 부착 라인 제거** (`options.headers['Authorization'] = 'Bearer $token';`)

```
00:00 +5 -2: Some tests failed.
  [E] 액세스 토큰이 있으면 Authorization 헤더를 붙인다
  [E] 보호 경로에는 토큰을 붙인다 — logout은 login에 걸리지 않는다
```
→ 2개 테스트가 죽었다. **부착 로직을 지우면 테스트가 실패한다.**

**변이 B — `_isPublic`이 항상 false 반환**

```
00:00 +4 -3: Some tests failed.
  [E] 로그인 요청에는 Authorization을 붙이지 않는다
  [E] 공개 경로는 저장소를 읽지도 않는다
  [E] 백엔드의 공개 인증 경로 전부에 토큰을 붙이지 않는다
```
→ 3개 테스트가 죽었다. **공개 경로 판정을 망가뜨리면 테스트가 실패한다.**

두 변이 모두 원복 후 재실행 → `+7 All tests passed`.

---

## 3. `flutter_secure_storage` 11.1.1 API — 브리프와 **일치했다**

설치본(`~/.pub-cache/hosted/pub.dev/flutter_secure_storage-11.1.1/lib/flutter_secure_storage.dart`)
을 직접 읽어 확인:

- `const FlutterSecureStorage({iOptions, aOptions, lOptions, wOptions, webOptions, mOptions})`
  — **const 생성자 유지**, 전 파라미터 기본값 있음. `const FlutterSecureStorage()` 그대로 유효.
- `Future<String?> read({required String key, ...})` ✓
- `Future<void> write({required String key, required String? value, ...})` ✓
- `Future<void> delete({required String key, ...})` ✓

메이저 버전이 높았지만 브리프가 쓰는 표면은 바뀌지 않았다. 브리프 코드 그대로 쓸 수 있었다.

한 가지만 손봤다(동작 변화 없음): 브리프의
`SecureTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();`
를 const 기본 파라미터
`const SecureTokenStorage([FlutterSecureStorage storage = const FlutterSecureStorage()])`
로 바꿔 `const SecureTokenStorage()` 인스턴스화가 가능하게 했다.

---

## 4. 인터셉터 테스트 방식을 바꾼 이유 (브리프 Step 2 폐기)

**브리프의 `RequestInterceptorHandler()..next(options)` 패턴은 dio 5.11.1에서 반드시 실패한다.**

dio 소스(`dio-5.11.1/lib/src/interceptor.dart`)에서 확인한 근거:

```dart
abstract class _BaseHandler {
  final _completer = Completer<InterceptorState>();
  void _throwIfCompleted() {
    if (_completer.isCompleted) {
      throw StateError('The `handler` has already been called, ...');
    }
  }
}

class RequestInterceptorHandler extends _BaseHandler {
  void next(RequestOptions requestOptions) {
    _throwIfCompleted();          // ← 여기
    _completer.complete(...);
  }
}
```

캐스케이드 `..next(options)`가 핸들러를 **미리 완료**시키므로, 구현이 `handler.next(options)`를
부르는 순간 `_throwIfCompleted()`가 `StateError`를 던진다. `await interceptor.onRequest(...)`가
그 에러를 되던져 **올바른 구현에 대해서도 3개 테스트 전부 실패**한다. 즉 브리프 테스트는
구현을 검증하지 못한다.

**대안 검토:**
- `handler.future`를 await → `future`가 `@protected`라 `invalid_use_of_protected_member`
  **warning**이 뜬다. `flutter analyze --no-fatal-infos`는 info만 무시하므로 verify.sh가 깨진다. 탈락.
- `mocktail`로 핸들러 모킹 → 가능하지만, 모킹한 핸들러는 dio의 실제 파이프라인이 아니라
  "인터셉터가 next를 불렀다"는 상호작용만 검증한다.
- **채택: 실제 `Dio` 인스턴스 + 가짜 `HttpClientAdapter`.** 소켓을 열지 않고 인터셉터 체인을
  **통과한 뒤의 최종 `RequestOptions`**를 붙잡는다. 브리프 의도(헤더가 붙었는가)를 실제
  dio 동작으로 검증하고, 인터셉터가 `next()`를 안 불러 요청이 멈추는 사고까지 잡는다.

결과적으로 `mocktail`은 이 태스크에서 쓰이지 않았다(아래 우려사항 참조).

부수 확인: dio는 헤더 키를 소문자화하지 않는다(`options.dart`의 `toLowerCase()`는 content-type
중복 assert 용도뿐). 그래서 `headers['Authorization']` 대소문자 그대로 단언해도 안전하다.

---

## 5. `_publicPaths` 판정 검증 — **브리프 목록에 죽은 항목 2개가 있어 고쳤다**

백엔드 레포(`~/workspace/personal/tobehealthy/backend`)의 실제 매핑을 전수 조사했다.

```
$ grep -rnE '@(Get|Post|...)Mapping\((value\s*=\s*)?"[^"]*(login|join|refresh|find)[^"]*"' --include='*.java' .
MemberAuthController.java:47:        @PostMapping("/find/user-id")
MemberAuthCommandController.java:49:  @PostMapping("/join")
MemberAuthCommandController.java:55:  @PostMapping("/login")
MemberAuthCommandController.java:61:  @PostMapping("/refresh-token")
MemberAuthCommandController.java:67:  @PostMapping("/find/password")
```

두 컨트롤러 모두 `@RequestMapping("/api/v1/auth")`. 즉 실제 공개 경로는
`/api/v1/auth/{login,join,refresh-token,find/user-id,find/password}`.

**브리프 목록 `['login','join','refresh','find-id','find-password']` 판정:**

| 항목 | 결과 |
|------|------|
| `login` | `/api/v1/auth/login` 매치 ✓ |
| `join` | `/api/v1/auth/join` 매치 ✓ |
| `refresh` | `/api/v1/auth/refresh-token` 매치 ✓ |
| `find-id` | **아무것도 매치 못 함** — 실제 경로는 `/find/user-id` ✗ |
| `find-password` | **아무것도 매치 못 함** — 실제 경로는 `/find/password` ✗ |

**오탐(false positive) 조사:** 백엔드 전체 매핑 경로를 뽑아 대조한 결과, `login`/`join`/
`refresh`를 부분 문자열로 포함하는 경로는 위 5개(전부 진짜 공개 경로)뿐이었다. 특히
**`/api/v1/auth/logout`은 `login`을 부분 문자열로 포함하지 않아** 잘못 제외되지 않는다.

**적용한 수정** — 실측 경로에 맞추고 `/auth/`로 앵커링:

```dart
static const List<String> _publicPaths = <String>[
  '/auth/login',
  '/auth/join',
  '/auth/refresh-token',
  '/auth/find/',
];
```

앵커링 이유: 공개 엔드포인트가 전부 `/api/v1/auth` 아래에 있으므로, 미래에 다른 컨트롤러에
`.../login-history` 같은 경로가 생겨도 오탐이 나지 않는다. 이 성질을 테스트로 고정했다
(`/api/v1/members/login-history`가 보호 경로로 판정되는지 — 가상 경로임을 주석에 명시).

**테스트로 고정한 판정 결과:**
- 토큰 **안 붙음**: `/api/v1/auth/login`(= `AuthApi.signInPath`), `/join`, `/refresh-token`, `/find/user-id`, `/find/password`
- 토큰 **붙음**: `/api/v1/members/me`, `/api/v1/auth/logout`, `/api/v1/schedule/student`, `/api/v1/workout-histories`, `/api/v1/gyms`, `/api/v1/members/login-history`

---

## 6. 검증 결과

```
$ ./tool/verify.sh
== dart format ==      Formatted 23 files (0 changed)
== flutter analyze ==  No issues found! (ran in 2.9s)
== har_to_golden.py == Ran 14 tests ... OK
== flutter test ==     00:01 +53: All tests passed!
OK: 모든 검증 통과
EXIT=0
```

Dart 46 → **53** (+7), Python 14 유지. 4단계 전부 통과.

중간에 `flutter analyze`가 페이크의 쓰이지 않는 생성자 파라미터를
`unused_element_parameter` **warning**으로 잡아 실패시켰고(verify.sh는 `set -euo pipefail`),
페이크에서 미사용 스캐폴딩(`refresh` 생성자 파라미터, `clearCount`)을 제거해 해결했다.

---

## 7. 셀프 리뷰

- **YAGNI / 401 갱신**: 넣지 않았다. `AuthInterceptor`는 `onRequest`만 가지며 `onError`가 없다.
  토큰 갱신·재시도·큐잉 코드는 한 줄도 없다. Phase 1 범위임을 클래스 주석에 명시.
- **baseUrl Global Constraint**: `DioClient.create`는 `baseUrl`을 그대로 `BaseOptions`에 넘기고,
  경로 접두사를 어디에서도 붙이지 않는다. `AuthApi.signInPath`가 `/api/v1/auth/login` 전체
  경로를 들고 있어 `RequestOptions.path`가 HAR 골든의 전체 경로와 그대로 대응한다.
  이 제약을 `dio_client.dart` 주석에 남겨 다음 사람이 되돌리지 않게 했다.
- **인터페이스 분리**: `TokenStorage`가 `abstract interface class`이고 테스트가 `_FakeStorage`를
  끼운다 — 계획 의도대로.
- **테스트 출력 청결도**: 실패·경고·미처리 예외 출력 없음. `+53 All tests passed!`만 나온다.
- **파일 크기**: 최대 파일이 `auth_interceptor.dart` 50줄. 계획 의도를 넘지 않았다.
- 커밋 후 워킹 트리 clean, 브랜치 변경 없음.

---

## 7-1. 네이티브 플랫폼 하한선 점검 (verify.sh가 덮지 못하는 영역)

`verify.sh` 4단계는 전부 Dart VM에서 돈다. 이번 커밋이 **네이티브 코드를 가진 플러그인
(`flutter_secure_storage`)을 처음 추가**했으므로, 플러그인이 요구하는 SDK 하한선이 앱보다
높으면 `flutter build apk` / `build ios`가 깨진다 — 어떤 Dart 테스트로도 드러나지 않는다.
빌드를 돌리는 대신 양쪽 하한선을 직접 읽어 대조했다.

| 축 | 앱 설정 | 플러그인 요구 | 판정 |
|----|---------|---------------|------|
| Android `minSdk` | `flutter.minSdkVersion` = **24** (`FlutterExtension.kt:26`) | `flutter_secure_storage` **24**, `jni`/`jni_flutter` 21 | 충족 (여유 0) |
| Android `compileSdk` | `flutter.compileSdkVersion` = **36** (`FlutterExtension.kt:23`) | `jni`/`jni_flutter` **35** | 충족 |
| iOS deployment target | `IPHONEOS_DEPLOYMENT_TARGET` = **13.0** | `flutter_secure_storage_darwin` 0.4.2 → `s.ios.deployment_target = '13.0'` | 충족 (여유 0) |

`android/app/build.gradle.kts`는 `minSdk = flutter.minSdkVersion`으로 Flutter 기본값을 그대로
따르므로 **하드코딩 수정이 필요 없었다.** 커밋 수정(amend) 없이 넘어간다.

**여유가 0인 축이 둘(Android minSdk 24, iOS 13.0)이다.** 이후 태스크가 더 높은 하한선을
가진 플러그인을 추가하면 그때는 `android/app/build.gradle.kts`와 Xcode 설정을 같이
올려야 한다.

한계: **실제 네이티브 빌드(`flutter build apk` / `build ios`)는 이번에도 돌리지 않았다.**
하한선 불일치는 위 대조로 배제했지만, Gradle/CocoaPods 레벨의 다른 충돌까지 배제한 것은
아니다. Phase 0에 네이티브 빌드 게이트가 없으므로 후속 계획에서 한 번은 실기기/에뮬레이터
빌드를 태우길 권한다.

---

## 8. 우려사항 (DONE_WITH_CONCERNS 사유)

1. **`mocktail`이 미사용 dev 의존성으로 남았다.** 브리프 Step 1이 명시적으로 추가를
   지시했지만, 채택한 테스트 방식(가짜 어댑터)이 목을 필요로 하지 않았다. 이후 태스크가
   쓸 것을 전제하고 **제거하지 않았다** — 지우면 Task 7+ 브리프의 전제가 깨질 수 있다.
   후속 태스크에서도 안 쓰이면 그때 제거를 권한다. `flutter_riverpod`·`go_router`도
   같은 이유로 현재 미사용이다(Task 7+ 용).
2. **`SecureTokenStorage`에 테스트가 없다.** 플랫폼 채널 위임 래퍼라 테스트 바이너리에서
   그대로 돌지 않는다. 키 이름(`access_token`/`refresh_token`) 오타나 `writeTokens`가 한쪽만
   쓰는 실수는 현재 어떤 테스트도 잡지 못한다. 패키지가
   `lib/test/test_flutter_secure_storage_platform.dart`를 제공하므로 **후속 태스크에서
   플랫폼 페이크로 검증 가능**하다. 브리프 파일 목록 밖이라 이번엔 추가하지 않았다.
3. **`AuthApi.signIn`이 어떤 테스트에서도 실행되지 않는다.** 테스트는 정적 상수
   `AuthApi.signInPath`만 읽는다. 명시해 둘 실패 모드가 하나 있다 — `response.data!`는
   서버가 빈 바디나 비-객체 JSON을 주면 한 줄 뒤 `SignInResponse.fromJson`이 의도적으로
   던지는 `FormatException`이 아니라 **밋밋한 null-check 오류**로 터진다. 브리프 코드
   그대로이고 Phase 0에서는 수용 가능하지만, 실서버 응답을 태우는 Task 7 패리티/통합
   시점에 한 번 짚고 갈 지점이다.
4. **`DioClient.create` 자체에 테스트가 없다.** `storage != null`일 때 `AuthInterceptor`가
   실제로 등록되는지, `extra` 인터셉터가 붙는지는 미검증이다. 인터셉터 테스트는 `Dio`를
   직접 만들어 인터셉터를 격리 검증하므로 이 조립부는 덮지 않는다. Task 7의 패리티
   테스트가 조립 경로를 태우면 자연히 덮인다 — 안 덮이면 `dio_client_test.dart`가 필요하다.
5. **`_publicPaths`가 `validation/*`·`access-token/*`(소셜 로그인)·`invitation/uuid`를
   포함하지 않는다.** 이들도 실제로는 공개 엔드포인트다. Phase 0 범위(로그인)를 넘고
   브리프 목록에도 없어 추가하지 않았다. 해당 시점에는 토큰이 없어 헤더가 붙지 않으므로
   실무상 무해하지만, 로그아웃 없이 재가입/소셜 연동을 타는 흐름이 생기면 재검토가 필요하다.
6. **`_sendThrough` 헬퍼는 모든 경로를 GET으로 보낸다.** 실제 로그인은 POST지만
   `_isPublic`은 경로만 보므로 판정에 영향이 없다. 메서드별 분기가 생기면 테스트도 바뀌어야 한다.
7. **절차 메모:** 이 태스크는 서브에이전트로 실행됐고, 사용자 전역 규칙
   (`~/.claude/rules/advisor-usage.md`, "서브에이전트 안에서는 advisor를 호출하지 않는다")에
   따라 advisor를 호출하지 않았다. 불확실했던 두 지점(secure storage API, 인터셉터 테스트
   패턴)은 조언이 아니라 **설치된 패키지 소스와 백엔드 실측**으로 해소했다.

---

# Fix 라운드 1 — 리뷰 반영

**Commit:** `f1c9cc3` fix(network): 미사용 의존성 제거·로그인 응답 바디 가드·DioClient 조립 검증
**검증:** `./tool/verify.sh` EXIT=0 — format 0 changed / analyze No issues / Python 14 / **Dart 53 → 60**

지시 5건 전부 반영했다. deferred 2건(`_publicPaths`의 `validation/*`·`access-token/*`·`invitation/uuid`,
`SecureTokenStorage` 자체 테스트)은 지시대로 손대지 않았다.

---

## Fix 1 — 미사용 의존성 3개 제거

```bash
$ flutter pub remove flutter_riverpod go_router mocktail
- riverpod 3.4.3
- state_notifier 1.0.0
- uuid 4.6.0
Changed 12 dependencies!
```

`pubspec.yaml` 최종 의존성: `cupertino_icons`, `dio ^5.11.1`, `flutter_secure_storage ^11.1.1`
(dev: `flutter_test`, `flutter_lints ^6.0.0`). 제거로 12개 패키지(전이 포함)가 트리에서 빠졌다.

### Flutter SDK 하한선 변화 — **원인은 `flutter_secure_storage`가 아니라 `go_router`였다**

| 시점 | `pubspec.lock`의 `sdks.flutter` | 원인 패키지 |
|------|-------------------------------|-------------|
| Task 6 이전 (`HEAD~2` = `d43cab2`) | `>=3.18.0-18.0.pre.54` | — |
| Task 6 커밋 (`081fae9`, 4개 추가) | **`>=3.44.0`** | **`go_router 18.0.1`** (`environment.flutter: ">=3.44.0"`) |
| Fix 1 이후 (`f1c9cc3`) | **`>=3.38.4`** | **`path_provider_foundation 2.6.0`** — `flutter_secure_storage`의 전이 의존(`_linux`/`_windows` 경유) |

근거 (각 패키지 `pubspec.yaml`의 `environment.flutter` 전수 대조):

```
>=3.38.4   path_provider_foundation-2.6.0   ← 현재 하한선을 결정
>=3.38.0   path_provider-2.1.6 / _linux / _platform_interface
>=3.35.6   jni-1.0.3, jni_flutter-1.0.3
>=3.19.0   flutter_secure_storage-11.1.1, flutter_secure_storage_darwin-0.4.2
>=3.44.0   go_router-18.0.1                 ← 제거됨
```

즉 **컨트롤러의 예상("제거 후에도 올라간 채면 `flutter_secure_storage` 탓")은 맞았지만, `3.44.0`까지
끌어올린 범인은 `go_router`였다.** `flutter_secure_storage` 본체가 요구하는 건 `>=3.19.0`이고,
남은 `>=3.38.4`는 그 전이 의존인 `path_provider_foundation` 몫이다. 설치된 Flutter는 3.47.0이라
두 시점 모두 충족하지만, 제거로 **하한선이 5.6 마이너 버전만큼 내려갔다**(3.44.0 → 3.38.4).

---

## Fix 2 — 존재하지 않는 `/api/v1/auth/logout` 정정

`auth_interceptor.dart` 주석과 `auth_interceptor_test.dart`의 보호 경로 목록 두 곳을
**`/api/v1/members/logout`**으로 바꿨다. 이제 테스트가 가상 경로가 아니라 실제 로그아웃
엔드포인트를 덮는다. 리포트 §5의 "실측" 표기 오류도 이 절로 정정한다 —
`/api/v1/auth/logout`은 스냅샷에 존재하지 않는다.

`logout`이 `login`을 부분 문자열로 포함하지 않는다는 성질은 경로가 바뀌어도 그대로이므로
가드로서의 역할은 유지된다.

---

## Fix 3 — `response.data!` 가드 + 덮는 테스트

```dart
final body = response.data;
if (body == null) {
  throw const FormatException('로그인 응답 바디가 비었다');
}
return SignInResponse.fromJson(body);
```

새 파일 `test/entity/auth/auth_api_test.dart` (4 케이스):
정상 envelope 파싱 / POST 경로·바디 확인 / **빈 바디 → FormatException** / `data: null` envelope는
`SignInResponse`의 진단 메시지를 그대로 전달.

```
$ flutter test test/entity/auth/auth_api_test.dart
00:00 +4: All tests passed!
```

**변이 C — 가드를 지우고 `response.data!`로 되돌림:**

```
00:00 +2 -1: AuthApi.signIn 바디가 비면 진단 가능한 FormatException을 던진다 [E]
     Which: threw _TypeError:<Null check operator used on a null value>
00:00 +3 -1: Some tests failed.
```

출력이 리뷰 지적을 그대로 재현한다 — 가드가 없으면 `FormatException`이 아니라
**`Null check operator used on a null value`**가 난다. 원복 후 `+4 All tests passed`.

---

## Fix 4 — `DioClient.create`를 테스트가 실제로 통과하게

`_sendThrough`가 손으로 `Dio(BaseOptions(...))..interceptors.add(...)`를 재현하던 것을
**운영과 같은 `DioClient.create(baseUrl:, storage:, extra:)` 호출로 교체**했다.
추가로 `DioClient.create 조립` 그룹 3 케이스: `extra` 인터셉터 체인 진입 /
`storage == null`이면 `AuthInterceptor` 미부착 / `baseUrl`이 경로 접두사를 삼키지 않음.

**변이 D — `if (storage != null) { dio.interceptors.add(AuthInterceptor(...)); }` 제거:**

```
00:00 +8 -2: Some tests failed.
```
→ 2개 사망. **수정 전이었다면 이 변이는 0개를 죽였다** (헬퍼가 팩토리를 안 탔으므로).

**변이 E — `dio.interceptors.addAll(extra);` 제거:**

```
00:00 +9 -1: Some tests failed.
```
→ Task 7 패리티 하네스의 주입 지점(`extra`)이 이제 회귀 방지된다.

두 변이 모두 유일 문자열 역치환으로 원복(§2와 같은 이유로 `git checkout` 미사용) 후
`+10 All tests passed`.

---

## Fix 5 — 안드로이드 암호화 방식 표기 정정

`token_storage.dart`의 "Keychain / EncryptedSharedPreferences"를 아래로 교체했다.

```dart
/// iOS/macOS는 Keychain, Android는 AES-GCM으로 값을 암호화하고 그 키를
/// KeyStore의 RSA-OAEP(SHA-256/MGF1)로 래핑한다 — Jetpack
/// `EncryptedSharedPreferences`가 아니다(`AndroidOptions` 기본값 참조).
```

근거는 `flutter_secure_storage-11.1.1/lib/options/android_options.dart:35-58` —
`keyCipherAlgorithm` 기본값이 `RSA_ECB_OAEPwithSHA_256andMGF1Padding`,
`storageCipherAlgorithm` 기본값이 `AES_GCM_NoPadding`이다.

---

## Fix 라운드 검증 결과

```
$ ./tool/verify.sh
== dart format ==      Formatted 24 files (0 changed)
== flutter analyze ==  No issues found! (ran in 2.7s)
== har_to_golden.py == Ran 14 tests ... OK
== flutter test ==     00:01 +60: All tests passed!
OK: 모든 검증 통과
EXIT=0
```

Dart **53 → 60** (+3 DioClient 조립, +4 AuthApi). Python 14 유지.

## 남은 우려사항 (갱신)

원 리포트 §8의 1번(미사용 의존성)·3번(`AuthApi.signIn` 미검증)·4번(`DioClient.create` 미검증)은
이 라운드로 **해소됐다.** 남는 것:

- **2번** `SecureTokenStorage` 자체 테스트 없음 — 컨트롤러 판단대로 첫 호출부가 생기는 태스크로 이월.
- **5번** `_publicPaths`가 `/auth/validation/*`·`/auth/access-token/*`·`/auth/invitation/uuid` 누락 — Phase 1로 이월.
- **6번** `_sendThrough`가 모든 경로를 GET으로 보냄(`_isPublic`이 경로만 보므로 판정에 무영향).
- **§7-1** 네이티브 빌드 미실행. 의존성 3개 제거로 네이티브 플러그인 표면이 오히려 줄었고
  (`flutter_secure_storage` 계열만 남음), Android minSdk 24 / compileSdk 36 / iOS 13.0 하한선
  판정은 그대로 충족이다.
