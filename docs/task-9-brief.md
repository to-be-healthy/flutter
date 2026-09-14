## Task 9: 참조 화면(로그인) + 팽창률 실측 + Phase 0 종료 게이트

Phase 0의 마지막이자 **Phase 1~8 공수 산정의 근거를 만드는 태스크**다. 웹 `SignInPage.tsx`(59줄) + `SignInForm.tsx`(118줄) = 177줄이 Flutter에서 몇 줄이 되는지 재고, 그 비율로 나머지 도메인을 역산한다.

**Files:**
- Create: `flutter/lib/page/public/sign_in_page.dart`
- Create: `flutter/lib/app.dart`
- Modify: `flutter/lib/main.dart`
- Create: `flutter/tool/measure_expansion.sh`
- Test: `flutter/test/page/sign_in_page_test.dart`

**웹 대비 의도적 생략** (Phase 1에서 추가):
- 로고 아이콘 (`IconLogo` 64x64) — SVG 자산 이식은 Phase 2 범위
- 회원가입 버튼(outline variant) · "비밀번호 찾기 / 아이디 찾기" 링크 — 라우팅이 없어 Phase 1 전에는 동작 불가
- 뒤로가기 버튼의 `router.push('/')` — 라우터 부재

**Interfaces:**
- Consumes: `AppLayout`, `AppLayoutHeader` (Task 8), `AppButton`, `AppTextInput` (Task 7), `AuthApi`, `DioClient`, `TokenStorage` (Task 6), `SignInRequest`/`SignInResponse` (Task 5), `RequestCapture`/`expectParity` (Task 4)
- Produces: `SignInPage` — Phase 1 이후 화면 이식의 참조 패턴

- [ ] **Step 1: 실패하는 화면 + 패리티 테스트 작성**

`test/page/sign_in_page_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/core/network/dio_client.dart';
import 'package:geonganghaejim/core/theme/app_theme.dart';
import 'package:geonganghaejim/entity/auth/api/auth_api.dart';
import 'package:geonganghaejim/page/public/sign_in_page.dart';

import '../harness/parity_matcher.dart';
import '../harness/request_capture.dart';

void main() {
  group('SignInPage', () {
    late RequestCapture capture;
    late Dio dio;

    setUp(() {
      capture = RequestCapture();
      dio = DioClient.create(baseUrl: 'https://example.test', extra: [capture]);

      // 네트워크로 나가지 않도록 응답을 가로챈다.
      dio.httpClientAdapter = _StubAdapter();
    });

    Widget wrap() => MaterialApp(
          theme: AppTheme.light(),
          home: SignInPage(authApi: AuthApi(dio)),
        );

    testWidgets('아이디·비밀번호 입력과 로그인 버튼을 표시한다', (tester) async {
      await tester.pumpWidget(wrap());

      // 웹은 이메일이 아니라 아이디로 로그인한다 (CommandLoginMember.userId)
      expect(find.text('회원 로그인'), findsOneWidget); // student 기본값
      expect(find.text('아이디'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
      expect(find.text('로그인'), findsWidgets);
    });

    testWidgets('빈 입력으로 제출하면 오류를 표시하고 요청을 보내지 않는다',
        (tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('입력'), findsWidgets);
      expect(capture.captured, isEmpty);
    });

    testWidgets('로그인 요청이 웹과 동일한 형태로 나간다 (패리티)', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(find.byType(TextField).first, 'testuser');
      await tester.enterText(find.byType(TextField).last, 'password1234');
      await tester.tap(find.text('로그인').last);
      await tester.pumpAndSettle();

      // 손으로 적은 기대값이 아니라 웹에서 캡처한 골든과 대조한다.
      // 이 한 줄이 검증 루프 3의 실제 적용 지점이며,
      // Phase 1~8의 모든 화면이 같은 방식으로 검증된다.
      expectParity('login', capture.captured);
    });

    testWidgets('잘못된 경로로 요청하면 패리티가 실패한다 (하네스 자체 검증)',
        (tester) async {
      // 하네스가 실제로 불일치를 잡는지 확인한다.
      // "통과했다"가 아니라 "실패를 잡는다"가 검증의 근거다.
      final bogus = [
        const CapturedRequest(
          method: 'POST',
          path: '/api/v1/wrong/path',
          query: {},
          body: {'userId': 'x', 'password': 'y', 'memberType': 'STUDENT'},
        ),
      ];

      expect(
        () => expectParity('login', bogus),
        throwsA(isA<ParityFailure>()),
      );
    });
  });
}

/// 네트워크 없이 고정 응답을 주는 어댑터.
class _StubAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 백엔드 ApiResultTokens envelope 형태를 그대로 흉내낸다.
    return ResponseBody.fromString(
      '{"status":"success","message":"로그인 성공","data":'
      '{"memberId":1,"name":"홍길동","accessToken":"at","refreshToken":"rt",'
      '"userId":"testuser","memberType":"STUDENT","gymId":7}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
flutter test test/page/sign_in_page_test.dart
```
Expected: FAIL — `sign_in_page.dart` 없음

- [ ] **Step 3: SignInPage 구현**

`lib/page/public/sign_in_page.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../entity/auth/api/auth_api.dart';
import '../../entity/auth/model/sign_in_request.dart';
import '../../shared/ui/app_button.dart';
import '../../shared/ui/app_text_input.dart';
import '../../widget/app_layout.dart';

/// 웹 `src/page/public/ui/SignInPage.tsx` + `feature/auth/ui/SignInForm.tsx` 대응.
class SignInPage extends StatefulWidget {
  const SignInPage({
    required this.authApi,
    this.memberType = 'STUDENT',
    super.key,
  });

  final AuthApi authApi;

  /// 'STUDENT' | 'TRAINER'. 백엔드가 필수로 요구한다.
  /// 웹은 `/sign-in?type=student` 쿼리로 받는다 — 역할 선택 화면은 Phase 1.
  final String memberType;

  /// 웹 SignInPage와 동일한 분기.
  String get _title =>
      memberType == 'TRAINER' ? '트레이너 로그인' : '회원 로그인';

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _userIdError;
  String? _passwordError;
  String? _submitError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final userId = _userIdController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _userIdError = userId.isEmpty ? '아이디를 입력해 주세요.' : null;
      _passwordError = password.isEmpty ? '비밀번호를 입력해 주세요.' : null;
    });

    return _userIdError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await widget.authApi.signIn(
        SignInRequest(
          userId: _userIdController.text.trim(),
          password: _passwordController.text,
          memberType: widget.memberType,
        ),
      );
      // 토큰 저장·라우팅은 Phase 1에서 연결한다.
    } catch (_) {
      setState(() => _submitError = '로그인에 실패했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final spacing = theme.extension<AppSpacing>()!;

    // 웹 SignInPage는 `<Layout className='bg-white'>`로 셸 기본 배경(gray-100)을
    // 흰색으로 덮고, Contents 안쪽에 `px-7`을 직접 준다. 제출 버튼도
    // bottomArea가 아니라 폼 안에 있다(SignInForm의 `mt-[46px]` 블록).
    return AppLayout(
      backgroundColor: Colors.white,
      header: AppLayoutHeader(title: _title),
      contents: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.s7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: spacing.s10),
            AppTextInput(
              label: '아이디',
              controller: _userIdController,
              errorText: _userIdError,
            ),
            SizedBox(height: spacing.s8),
            AppTextInput(
              label: '비밀번호',
              controller: _passwordController,
              errorText: _passwordError,
              obscureText: true,
            ),
            if (_submitError != null) ...[
              SizedBox(height: spacing.s6),
              Text(
                _submitError!,
                style: AppTypography.body3.copyWith(color: colors.point),
              ),
            ],
            SizedBox(height: spacing.s12),
            AppButton(
              label: '로그인',
              onPressed: _submit,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
flutter test test/page/sign_in_page_test.dart
```
Expected: PASS (4 tests)

**패리티 테스트가 경로 불일치로 실패하면 `AuthApi.signInPath`를 고친다** — 골든이 정답이다. 테스트를 통과시키려고 골든을 수정하지 않는다.

- [ ] **Step 5: 앱 진입점 연결 후 실기기 확인**

`lib/app.dart`:

```dart
import 'package:flutter/material.dart';

import 'core/network/dio_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'entity/auth/api/auth_api.dart';
import 'page/public/sign_in_page.dart';

class GeonganghaejimApp extends StatelessWidget {
  const GeonganghaejimApp({required this.baseUrl, super.key});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final dio = DioClient.create(
      baseUrl: baseUrl,
      storage: SecureTokenStorage(),
    );

    return MaterialApp(
      title: '건강해짐',
      theme: AppTheme.light(),
      home: SignInPage(authApi: AuthApi(dio)),
    );
  }
}
```

`lib/main.dart`:

```dart
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://geonganghaejim.site',
  );

  runApp(const GeonganghaejimApp(baseUrl: baseUrl));
}
```

**실제 기기/시뮬레이터에서 띄워 눈으로 확인한다. 이 단계는 생략할 수 없다** — 위젯 테스트는 "Flutter가 그린 결과"만 검증하지 웹 디자인과 같은지는 증명하지 못한다.

```bash
flutter devices
flutter run --dart-define=API_BASE_URL=https://geonganghaejim.site
```

확인 항목 — 웹 로그인 화면을 나란히 띄우고 대조한다:
- [ ] 입력 필드 간격이 웹과 같은가 (spacing.s8 = 24px)
- [ ] 폰트가 Pretendard로 렌더되는가 (시스템 폰트로 폴백되지 않았는가)
- [ ] 버튼 색이 `#1990FF`인가
- [ ] 키보드가 올라올 때 하단 버튼이 가려지지 않는가
- [ ] 노치·홈 인디케이터를 침범하지 않는가

어긋나는 항목이 있으면 **테마 토큰을 고치지 말고** 무엇이 다른지 기록한 뒤, 원인이 토큰 값인지 레이아웃 구성인지 먼저 판별한다. 토큰 값이 원인이면 Task 2·3의 테스트부터 고친다.

- [ ] **Step 6: 팽창률 실측**

`tool/measure_expansion.sh`:

```bash
#!/usr/bin/env bash
# 웹 원본 대비 Flutter 구현의 줄 수 팽창률을 측정한다.
set -euo pipefail

WEB=/Users/seonwoo_jung/workspace/personal/tobehealthy/frontend
FLUTTER=/Users/seonwoo_jung/workspace/personal/tobehealthy/flutter

web_lines=$(cat \
  "$WEB/src/page/public/ui/SignInPage.tsx" \
  "$WEB/src/feature/auth/ui/SignInForm.tsx" \
  | wc -l | tr -d ' ')

flutter_lines=$(wc -l < "$FLUTTER/lib/page/public/sign_in_page.dart" | tr -d ' ')

echo "웹 원본 (SignInPage + SignInForm): ${web_lines}줄"
echo "Flutter (sign_in_page.dart):       ${flutter_lines}줄"

python3 - "$web_lines" "$flutter_lines" << 'EOF'
import sys
web, flu = int(sys.argv[1]), int(sys.argv[2])
ratio = flu / web
print(f"팽창률: {ratio:.2f}x")
print()
print("전체 UI 22,257줄 기준 역산:")
print(f"  예상 Dart UI 줄 수: {int(22257 * ratio):,}줄")
print()
print("주의: 이 수치는 폼 화면 1개 기준이다.")
print("리스트·그리드·캘린더가 많은 도메인은 팽창률이 더 클 수 있으므로")
print("Phase 3~5 착수 시 각 도메인 첫 화면에서 재측정할 것.")
EOF
```

```bash
chmod +x tool/measure_expansion.sh
./tool/measure_expansion.sh
```

측정 결과를 `../MOBILE_MIGRATION_ANALYSIS.md`의 "§3 줄 수 팽창률" 절에 **Flutter 실측치로 추가 기록한다.** 그 절은 현재 RN 수치만 있고 Flutter는 "실측 필요"로 비어 있다.

- [ ] **Step 7: Phase 0 종료 게이트**

아래를 **전부** 확인한다. 하나라도 미달이면 Phase 1로 넘어가지 않는다.

```bash
./tool/verify.sh
```

- [ ] `flutter analyze` 무경고
- [ ] `flutter test` 전체 통과 (Task 2·3·4·6·7·8·9의 테스트)
- [ ] spacing 매핑 테스트가 웹 비선형 스케일을 고정하고 있다
- [ ] 실기기에서 로그인 화면이 뜨고, 위 5개 시각 확인 항목을 통과했다
- [ ] 로그인 요청이 웹과 동일한 경로·본문으로 나간다
- [ ] 팽창률 실측치가 `MOBILE_MIGRATION_ANALYSIS.md`에 기록됐다

- [ ] **Step 8: 커밋**

```bash
git add lib tool test
git commit -m "feat(auth): 로그인 참조 화면 구현 및 팽창률 실측 도구 추가"
```

**push하지 않는다.** 공유 브랜치 푸시는 사용자가 직접 요청할 때만 수행한다. Phase 0 완료 후 사용자에게 확인받는다.

---

## Self-Review

**1. Spec 커버리지** — `MOBILE_MIGRATION_ANALYSIS.md`의 Phase 0 관련 요구사항 대조:

| Spec 항목 | 대응 Task |
|---|---|
| §4 "spacing 매핑 테이블 — 자동 변환 전에 사람이 확정" | Task 2 (테스트로 고정) |
| §4 검증 루프 1 (analyze/format/compile) | Task 1 (`tool/verify.sh`) |
| §4 검증 루프 2 (위젯 테스트) | Task 7·8·9 |
| §4 검증 루프 3 (API 요청 패리티) | Task 4 (하네스) + Task 9 (적용) |
| §4 권장순서 1 "디자인 토큰 + 공통 위젯 수작업 확정" | Task 2·3·7·8 |
| §4 권장순서 2 "참조 화면 1~2개 + 팽창률 실측" | Task 9 |
| §4 권장순서 3 "API 모델은 OpenAPI에서" | Task 5 (스냅샷 확보, 생성기는 Phase 1로 연기) |
| §8 "Pretendard 9웨이트" | Task 3 (woff→otf 교체 포함) |
| §8 "번들 ID 승계" | Global Constraints + Task 1 Step 1 |

**미커버(의도적)**: 소셜 로그인(Phase 1), 캘린더·시간표(Phase 4·5), FCM(Phase 3), 네이티브 기능(Phase 9). Phase 0은 기반과 참조 패턴 확립이 목적이므로 범위 밖이다.

**2. 플레이스홀더 점검** — "TBD", "적절히 처리", "Task N과 유사" 없음. 한 곳만 의도적 미확정:
- ~~Task 5·6의 추측 경로~~ → **해소됨.** 컨트롤러가 배포 서버 `/v3/api-docs`를 조회해 실제 계약으로 교체했다: `POST /api/v1/auth/login`, 요청 `CommandLoginMember{userId, password, memberType(필수), complimentaryLogin}`, 응답 `ApiResultTokens{status, message, data(Tokens)}`. 계획에 적혀 있던 `/api/v1/members/login` + `{email, password}` + 평면 응답은 전부 틀렸었다.
- Task 4의 하네스 단위 테스트에 쓰인 `/api/v1/members/login`은 **실제 API와 무관한 더미 경로**다(비교 로직만 검증). 커밋된 코드와 일치하므로 그대로 둔다.

**3. 타입 일관성** — 태스크 간 참조 검증:
- `AppSpacing.standard` (Task 2) → Task 3 `AppTheme`, Task 7 위젯, Task 8 레이아웃에서 동일 이름 사용 ✓
- `AppColors.light` (Task 2) → Task 3·7·8·9 동일 ✓
- `TokenStorage` 인터페이스 4개 메서드 (Task 6) → 테스트 `_FakeStorage`가 `readRefresh` 포함 4개 전부 구현 ✓
- `AuthApi.signInPath` (Task 6) → Task 9 테스트가 동일 상수 참조 ✓
- `CapturedRequest` 필드 4개 (Task 4) → Task 9에서 `method`/`path`/`body` 사용 ✓
- `AppButton` 생성자 (Task 7) → Task 9에서 `label`/`onPressed`/`isLoading` 사용 ✓
- `AppLayout` 3슬롯 (Task 8) → Task 9에서 `header`/`contents`/`bottomArea` 사용 ✓

**4. 검증 루프가 실제로 돌아가는지 재확인** (1차 작성 시 결함이 있어 수정함):
- Task 4가 만든 `expectParity`/`loadGolden`/골든 픽스처를 **Task 9 Step 1이 실제로 호출한다.** 초안은 하드코딩 리터럴로 비교해 하네스가 아무 데서도 쓰이지 않았다.
- Task 9에 **하네스 자체 검증 테스트**를 뒀다 — 틀린 경로를 주면 `ParityFailure`가 나는지 확인한다. "통과했다"가 아니라 "실패를 잡는다"가 검증의 근거다.
- 마찬가지로 Task 1 Step 4에서 `verify.sh`가 고장을 실제로 잡는지 먼저 확인한다.

**알려진 한계** (실행 중 조정 필요할 수 있음):
- Task 7 Step 1의 `find.byType(Container)` 매처는 `AppButton` 내부 구조가 바뀌면 깨진다. 구현이 확정된 뒤 `find.byKey`로 바꾸는 편이 견고하다.
- Task 6 Step 2의 `RequestInterceptorHandler()..next(options)` 패턴은 dio 버전에 따라 동작이 다를 수 있다. 실패하면 `mocktail`로 핸들러를 모킹한다.
- Task 9의 `_StubAdapter`는 모든 요청에 동일 응답을 준다. 실패 경로 테스트가 필요해지면 경로별 분기를 추가한다.
- `kMaskedKeys`(Dart)와 `MASKED_KEYS`(Python)는 **손으로 동기화해야 한다.** 한쪽만 고치면 골든에 평문이 남거나 비교가 어긋난다. 키를 추가할 때 양쪽을 함께 고친다.
- 골든 픽스처는 캡처 시점의 웹 동작을 고정한다. 웹이 요청을 바꾸면 골든을 다시 떠야 하며, 그때는 **웹 변경이 의도된 것인지 먼저 확인한다.**
