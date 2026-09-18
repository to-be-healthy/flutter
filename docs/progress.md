> **다음에 무엇을 할지는 `next-steps.md`에 있다.** 이 파일은 "왜 그렇게
> 결정했나"의 시간순 원장이고, 남은 작업 목록이 아니다.

# SDD ledger — plan: /Users/seonwoo_jung/workspace/personal/tobehealthy/docs/superpowers/plans/2026-09-13-flutter-migration-phase0.md

Spec: /Users/seonwoo_jung/workspace/personal/tobehealthy/MOBILE_MIGRATION_ANALYSIS.md (읽음)
작업 레포: /Users/seonwoo_jung/workspace/personal/tobehealthy/flutter
브랜치: feature/flutter-phase0 (base: d836702 Initial commit)

## 셋업 Rulings

Ruling: 계획 Task 9 Step 8의 `git push origin develop` 제거 — 공유 브랜치 푸시는 스킬의 stop-and-ask 항목이고 사용자 CLAUDE.md("커밋·푸시는 사용자가 요청할 때만")에도 걸린다. Phase 0 완료 후 사용자에게 확인받는다 — 틀렸을 경우 비용: 사용자가 푸시를 원했다면 한 번 더 요청해야 함(사소).

Ruling: git worktree 대신 feature 브랜치 사용 — 계획 전문이 `/Users/.../tobehealthy/flutter` 절대경로를 가정하므로 워크트리를 쓰면 경로가 전부 어긋난다. 레포가 사실상 비어 있어(추적 파일 1개) 격리할 기존 작업도 없다 — 틀렸을 경우 비용: develop이 오염될 수 있으나 브랜치 분리로 방지됨, 되돌리기 쉬움.

Ruling: 모델 배치 — Task 1·2·3·7·8은 Sonnet 5(계획에 코드가 전부 있는 전사 성격), Task 4·5·6·9는 Opus 5(스펙 대조·패리티 불일치 등 판단 필요). 사용자와 합의됨 — 틀렸을 경우 비용: 품질 부족 시 fix 라운드 추가.

## 사전 충돌 스캔

### 태스크 쌍 — 파일·인터페이스 공유

| 쌍 | 공유 대상 | 생산 → 소비 | 결과 |
|---|---|---|---|
| T1 → T3 | `pubspec.yaml` | T1이 생성, T3이 `fonts:` 추가 | ⚠️ T3은 기존 `flutter:` 섹션을 **대체하지 말고 병합**해야 함 → 브리프에 명시 |
| T1 → T6 | `pubspec.yaml` | T1 생성, T6이 의존성 추가 | OK (순차) |
| T1 → T9 | `lib/main.dart` | T1 생성, T9 교체 | OK (순차) |
| T2 → T3 | `AppSpacing.standard`/`AppColors.light`/`AppRadius.standard` | T2 정의, T3 `AppTheme`가 주입 | OK — 이름 일치 확인 |
| T2·T3 → T7 | 테마 extension 4종 | T7 위젯이 `Theme.of(context).extension<...>()` | OK |
| T2·T3 → T8 | 동일 | T8 레이아웃이 소비 | OK |
| **T4 → T6** | **`package:dio/dio.dart`** | **T4 `request_capture.dart`가 dio import, dio 추가는 T6 Step 1** | ❌ **충돌 — 아래 Ruling** |
| T4 → T9 | `expectParity`/`CapturedRequest`/`ParityFailure` | T4 정의, T9 호출 | OK (수정본에서 실제 호출 확인) |
| T4 → T5 | `test/fixtures/requests/login.json` | T4 Step 7 생성, T5가 경로·키 근거로 사용 | OK (순차) |
| T5 → T6 | `SignInRequest`/`SignInResponse` | T5 정의, T6 `AuthApi`가 사용 | OK |
| T6 → T9 | `AuthApi`/`DioClient`/`SecureTokenStorage` | T6 정의, T9 사용 | OK |
| T7·T8 → T9 | `AppButton`/`AppTextInput`/`AppLayout` | T7·T8 정의, T9 조립 | OK — 생성자 시그니처 일치 확인 |

### 태스크 자체 정합성

| Task | 테스트 ↔ 구현 | 파일 생성 ↔ 이후 수정 | 결과 |
|---|---|---|---|
| T1 | verify.sh가 실패를 잡는지 자체 확인 단계 있음 | — | OK |
| T2 | `lerpDouble` static 사용 ↔ 구현에 존재 | — | OK |
| T3 | 16종 스타일 ↔ `AppTypography.all` 목록 일치 | pubspec 수정 | OK |
| T4 | `diffRequests` 8 테스트 ↔ 마스킹 구현 | — | OK |
| T5 | DTO 키 ↔ OpenAPI 스냅샷 대조 테스트 | 백엔드 외부 의존(대체 절차 명시됨) | OK |
| T6 | `_FakeStorage` 4메서드 ↔ `TokenStorage` 인터페이스 4개 | — | OK |
| T7 | `find.byType(Container)` ↔ AppButton 내 Container 1개 | — | OK (한계 기록됨) |
| T8 | `find.byType(SingleChildScrollView)` ↔ 구현 사용 | — | OK |
| T9 | `expectParity` 호출 ↔ T4 하네스 | main.dart 교체 | OK |

Ruling: **T4에 dio 의존성 추가 단계를 선행시킨다.** T4의 `request_capture.dart`가 `package:dio/dio.dart`를 import하는데 dio 추가는 T6 Step 1이라 T4 시점에 컴파일이 깨진다. T4 브리프 맨 앞에 `flutter pub add dio` 를 넣고, T6 Step 1은 그대로 둔다(이미 있는 패키지 재추가는 무해) — 틀렸을 경우 비용: 없음. 순서만 앞당기는 변경이며 T6의 동작은 불변.

Ruling: **사용자 개입 지점 2곳에서 멈춘다.** T4 Step 7(웹에서 HAR 캡처)과 T9 Step 5(실기기 확인)는 사람만 할 수 있다. 해당 지점에 도달하면 그때까지의 결과를 보고하고 사용자 작업을 요청한다 — 틀렸을 경우 비용: 없음. 물리적으로 대안이 없다.

## 진행 기록

Task 1: dispatched (sonnet, BASE d836702) — 프로젝트 생성 + 검증 파이프라인
Task 1: implementer DONE (commit 02c1d67) — 번들 ID가 `com.geonganghaejim.geonganghaejim`으로 잘못 생성된 것을 발견해 `com.geonganghaejim.app`로 수정(build.gradle.kts, project.pbxproj 6곳, MainActivity.kt 패키지·경로). README.md 덮어쓰기 복원. verify.sh 실패 검출 확인(정상→파손→exit=1→복구→exit=0).
Ruling: Flutter 버전 문자열 불일치 수용 — 로컬이 `3.47.0-1.0.pre-79 (channel stable)`, 계획은 "3.47.0 stable"로 기재. Dart 3.12.2는 정확히 일치하고 constraint의 의도는 "이 설치본으로 개발한다"이지 문자열 매칭이 아니다. 계획의 Global Constraints를 실측치로 갱신해 이후 리뷰어의 반복 지적을 막았다 — 틀렸을 경우 비용: 없음(문서 정확도만 개선).
Task 1: task review dispatched (sonnet, d836702..02c1d67, 68 files/2014 insertions)
Task 1: review clean — Spec ✅ compliant, quality Approved. Critical 0 / Important 0 / Minor 1.
Ruling: 리뷰어의 ⚠️(Flutter가 `3.47.0-1.0.pre-79`로 tagged stable이 아닐 수 있음) 해소 — 실측 환경을 기준으로 삼는다. Dart 3.12.2 정확 일치, flutter create/analyze/test 전부 동작, SDK 교체는 이 계획 범위 밖이며 사용자 환경 결정사항이다. 계획 constraint는 이미 실측치로 갱신됨 — 틀렸을 경우 비용: 다른 기기·CI에서 SDK 차이로 재현 문제가 날 수 있음(사용자에게 고지함).
Task 1: minor (deferred): lib/main.dart의 `Colors.deepPurple`가 "리터럴 금지" constraint 위반 — flutter create 보일러플레이트이며 Task 9가 main.dart를 교체하면서 자동 해소됨. 최종 리뷰에서 확인할 것.
Task 1: complete (commits d836702..02c1d67, review clean)
Task 2: dispatched (sonnet, BASE 02c1d67) — 디자인 토큰 spacing/색상/radius
Task 2: implementer DONE (commit eaed9ef) — 7/7 통과, verify.sh 전 단계 clean. Concern: RED 단계 에러 문구가 브리프 Expected(`Target of URI doesn't exist`)와 달랐음(`Error when reading '...': No such file or directory`) — 근본 원인 동일(파일 부재로 컴파일 실패), SDK 버전 문구 차이. 기능 영향 없음.
Task 2: 컨트롤러 자체 점검 — 웹 원본(tailwind.config.js·global.css) 대비 토큰 36개 전수 대조: spacing 12개 일치 ✓, 색상 21개 일치(알파 FF 포함) ✓, radius 3개 일치 ✓. Phase 0 최대 위험 지점(비선형 spacing) 통과.
Task 2: task review dispatched (sonnet, 02c1d67..eaed9ef)
Task 3 사전 검증(컨트롤러): Pretendard v1.3.9가 실제 최신 태그이고 `Pretendard-1.3.9.zip`(45MB) 다운로드 성공. 계획이 가정한 zip 내부 경로 `public/static/*.otf`가 정확히 맞고 9웨이트 파일명도 계획의 pubspec 선언과 일치 확인. zip을 스크래치패드에 받아뒀으므로 implementer는 재다운로드 불필요. 웹 `public/fonts/`에는 subset woff만 있어(Flutter 미지원) 다운로드가 맞는 경로임도 확인.
Ruling: 폰트 9웨이트 전부 포함(계획대로 유지) — 타이포 16종이 실제로 쓰는 웨이트는 400/500/600/700 4개뿐이라 나머지 5개(100/200/300/800/900, 약 7.5MB)는 번들 크기만 늘린다. 그럼에도 웹이 9개 @font-face를 선언하므로 parity가 기본값이고, 번들 최적화는 실측 후 결정할 문제이지 Phase 0의 목적이 아니다 — 틀렸을 경우 비용: 앱 번들 약 7.5MB 초과, 나중에 pubspec에서 5줄 지우면 회수 가능.
Task 2: review clean — Spec ✅ compliant, quality Approved. Critical 0 / Important 0 / Minor 2. 리뷰어가 값을 digit-for-digit 독립 검증했고 컨트롤러 자체 대조와 일치.
Ruling: 리뷰어의 ⚠️(SDK 핀·번들 ID가 이 diff에 없음, Task 1에서 설정됐는지 확인 요청) 해소 — Task 1 리뷰가 번들 ID를 Android 2곳·iOS 6곳·MainActivity.kt까지 검증했고 컨트롤러도 grep으로 잔존 없음을 확인했다. 이 태스크 범위 밖이 맞다 — 틀렸을 경우 비용: 없음(이미 이중 검증됨).
Task 2: minor (deferred): AppColors/AppRadius의 `lerp()`에 테스트 없음(AppSpacing.lerp만 테스트됨). 브리프가 요구하지 않았고 형태가 동일한 보일러플레이트라 위험 낮음. 최종 리뷰에서 triage.
Task 2: minor (deferred): 리뷰어가 `lerpDouble`의 `dart:ui` 충돌 가능성을 명명된 리스크로 점검 → non-issue 확인(해당 파일은 material.dart만 import, 클래스 static 멤버가 우선 해소). 조치 불필요.
Task 2: complete (commits 02c1d67..eaed9ef, review clean)
Task 3: dispatched (sonnet, BASE eaed9ef) — Pretendard 폰트 + 타이포 16종 + AppTheme 조립
Task 3: implementer DONE (commit 22db71a) — 13/13 통과(기존 7 + 신규 6), verify.sh clean. Concerns 없음. implementer가 브리프 기대값뿐 아니라 웹 원본 typography.ts와도 직접 대조했다고 보고.
Task 3: 컨트롤러 자체 점검 — 웹 typography.ts 상수 19개 → Dart 16종 매핑 전수 대조: fontSize/height/fontWeight 전부 일치 ✓, 별칭 3쌍 통합 정확 ✓, 모든 스타일에 fontFamily 선언됨 ✓. 폰트 자산 9개(13MB) 존재 확인. pubspec `uses-material-design: true` 보존 확인 ✓(사전 스캔에서 잡은 병합 리스크 해소), weight 선언 100~900 9개 정확(grep이 flutter create 주석 1줄을 함께 센 것이었고 실제 중복 없음).
Task 3 사전조사(컨트롤러): 의존성 최신 버전 확인 — dio 5.11.1(계획의 _StubAdapter/인터셉터 시그니처는 dio 5.x 기준이므로 호환), flutter_secure_storage 11.1.1(메이저가 높아 Task 6에서 read/write/delete API 확인 필요), mocktail 1.0.5, go_router 18.0.1, flutter_riverpod 3.4.3.
Task 3: task review dispatched (sonnet, eaed9ef..22db71a)
Task 3: review clean — Spec ✅ compliant, quality Approved. Critical 0 / Important 0 / Minor 2. 리뷰어가 웹 typography.ts를 직접 읽어 19개 상수를 독립 대조했고, 폰트 바이너리를 `file`로 유효 OpenType인지 확인, pubspec 병합이 additive-only인지 live 파일로 검증.
Task 3: minor (deferred): `AppTypography.all`이 수동 유지 목록이라 새 스타일 추가 시 fontFamily 테스트 커버리지가 조용히 빠질 수 있음. 현재는 동기 상태. 주석 추가 권고.
Task 3: minor (deferred): `AppTheme.textTheme` 슬롯 매핑(titleMedium 등)에 테스트 없음 — 인접 슬롯 간 copy-paste 오류를 못 잡음. 화면이 주로 AppTypography.*를 직접 참조하므로 위험 낮음.
Task 3: complete (commits eaed9ef..22db71a, review clean)
Ruling: Task 4를 두 단계로 분할 — Step 1~6(하네스 코드 + 변환 스크립트)을 구현·커밋하고, Step 7(웹 HAR 캡처)은 사용자 작업이므로 거기서 멈춘다. 계획 Step 8의 커밋 범위에서 골든 픽스처를 빼고 `test/fixtures/requests/.gitkeep`만 커밋하도록 조정했다 — 틀렸을 경우 비용: 커밋이 하나 늘어남(사소).
Task 4: dispatched (opus, BASE 22db71a) — API 패리티 하네스. dio 선행 추가 ruling 적용, Step 7에서 정지 지시.
Task 4: implementer DONE_WITH_CONCERNS (commit 242509f) — 21개 테스트 통과, kMaskedKeys↔MASKED_KEYS 9키 기계 대조 일치, har_to_golden.py 합성 HAR 엔드투엔드 확인. 실측으로 결함 3건 + 커버리지 갭 1건을 스스로 보고.
Ruling: 우려 #2(baseUrl 접두사) — 하네스를 고치지 않고 **계약으로 해결**한다. `baseUrl`은 오리진만 담고 경로 접두사는 각 API path에 적는 제약을 Global Constraints에 추가했다. 계획의 `AuthApi.signInPath = '/api/v1/members/login'`이 이미 그 형태라 추가 작업 없음 — 틀렸을 경우 비용: Task 6에서 baseUrl을 다르게 쓰면 패리티 전체가 path 불일치로 실패(리뷰에서 잡힘).
Ruling: 우려 #1(쿼리 타입)·#3(FormData)·#4(회귀 테스트 부재)는 **fix 라운드로 지금 고친다** — #1은 무한스크롤 13개 화면에 걸리고 오탐 메시지가 원인 불명(`기대 0, 실제 0`)이라 디버깅 비용이 크다. #4는 expectParity·RequestCapture가 하네스의 핵심인데 커밋된 회귀 테스트가 없다. 브리프가 코드를 verbatim 지정해 implementer가 임의 수정을 삼간 것은 올바른 판단이었고, 계획 결함은 컨트롤러가 rule할 사안이다 — 틀렸을 경우 비용: 하네스가 복잡해짐(수정 범위는 작게 한정).
Task 4: fix round 1/5 (3 addressed, 0 open — 쿼리 타입 정규화(query만, body는 타입까지 비교하는 비대칭을 주석으로 명시) / 직렬화 불가 본문을 진단 메시지로 전환(FormData 비교는 미구현, Phase 7 안내) / 회귀 테스트 11개 추가(하네스 8→19); commits 242509f..ca1f8c3)
Task 4: 컨트롤러 자체 점검 — kMaskedKeys↔MASKED_KEYS 9키 차집합 없음 ✓, 골든 디렉터리에 .gitkeep만 존재(HAR 캡처 전 기대 상태) ✓, 테스트 총 32개(테마 12 + 하네스 19 + widget 1) ✓, coerceScalarTypes가 query=true/body=false로 의도된 비대칭 확인 ✓
Task 4: 남은 한계(implementer 보고, 범위 밖 유지): toString() 기반 정규화라 골든 리스트 ['a','b'] vs 문자열 "[a, b]"를 같게 보는 이론적 취약점 — 쿼리에서 나올 조합이 아니라고 판단. 마스킹 키 이중 관리(Dart/Python)와 요청 순서 비교도 범위 밖.
Task 4: task review dispatched (opus, 22db71a..ca1f8c3, 커밋 2개)
Task 4: review — Spec ❌ / quality Needs fixes. Important 5 / Minor 8. 리뷰어가 "이 하네스가 실제로 불일치를 잡는가"를 gut-test로 검증(비교 로직을 제거하면 어떤 테스트가 깨지는지 추적)해 핵심 속성은 성립함을 확인했으나, 신뢰를 깎는 갭 3개를 지적.
Ruling: Spec ❌ #1(`matchesGolden` Matcher 미구현) — **계획 결함이 맞다.** 브리프 Interfaces 줄이 `matchesGolden`을 선언했지만 같은 브리프 Step 4 코드는 `expectParity`를 정의한다. 리뷰어가 task-9-brief를 확인해 소비자도 `expectParity`를 쓴다고 검증했다. 구현자가 코드를 따른 것이 옳다. 계획의 stale Interfaces 줄을 실제 산출물(expectParity/loadGolden/kMaskedKeys)로 교체했다 — 틀렸을 경우 비용: 없음(문서 정확도만 개선). 구현자가 이 모순을 리포트의 "브리프 대비 의도적 차이" 절에 적지 않은 것은 사소한 누락.
Ruling: Important 5건 전부 + Minor 3건(#6 추가키 마스킹 누락=토큰 평문 노출, #8 keep_blank_values=검색화면 오탐, #12 에러 메시지의 Phase 번호 하드코딩)을 fix 라운드 2로 고친다. #6은 Minor로 분류됐으나 실계정 토큰이 실패 출력에 평문으로 찍히는 경로라 보안 사안으로 승격 — 틀렸을 경우 비용: fix 범위가 커져 라운드가 길어짐(각 수정은 지목 지점 한정).
Task 4: fix round 2 dispatched (Important 5 + Minor 3)
Task 4: fix round 2/5 (8 addressed 주장, 재리뷰 대기 — _diffMap 재귀화+_diffLeaf 분리 / har_to_golden_test.py 14개+HAR→loadGolden 계약 테스트+verify.sh 파이썬 단계 / 마스킹키 drift 가드 커밋 / 메시지에 인코딩·타입 표기+hasLength만 보던 단언 4곳 보강 / 빈 골든 차단(생성기 exit 1 + ParityFailure) / 추가키 마스킹 / keep_blank_values / 단계번호 제거; commits ca1f8c3..8e0ce13)
Task 4: implementer가 계약 테스트를 뮤테이션('path'→'pathx')으로 실제 검증하고 문자열 역치환으로 원복(git checkout 미사용), shasum 일치 확인 — 지시하지 않았는데 스스로 수행.
Task 4: 컨트롤러 자체 점검 — verify.sh:14에 `python3 -m unittest discover -s tool -p '*_test.py'` 존재, 실제 실행 시 Ran 14 확인 ✓ (implementer가 지시의 `discover tool` 기본 패턴이 `test*.py`라 파일명을 못 잡는 문제를 발견해 -p 옵션으로 교정)
Task 4: 남은 구멍(implementer 보고): 리스트 **안쪽** 맵은 여전히 리프 jsonEncode 비교 — Python mask()는 리스트 안까지 재귀 마스킹하므로 비대칭이 남아 있다. 지시 범위가 "중첩 Map"이라 넘지 않음. 최종 리뷰에서 triage.

=== 계획 정정 (컨트롤러, 배포 서버 OpenAPI 조회 결과) ===
Ruling: Task 5의 OpenAPI 획득 경로를 로컬 bootRun → **배포 서버 GET**으로 변경. `.env`의 DB_URL이 원격 DB(주소는 `backend/.env`의 `DB_URL` 참고)를 가리켜 로컬 기동이 운영 데이터에 붙을 위험이 있고, ingress가 `/v3/api-docs`를 backend로 라우팅해 인증 없이 HTTP 200으로 열려 있다(108 paths) — 틀렸을 경우 비용: 없음. 읽기 전용 GET이고 운영 DB를 건드리지 않는 더 안전한 경로다.
Ruling: **baseUrl 정정** — 계획의 `https://api.geonganghaejim.site`는 존재하지 않는 도메인. API는 웹앱과 같은 `https://geonganghaejim.site`이며 ingress가 `/api` prefix를 backend:8080으로 보낸다(webview/lib/main.dart:227이 그 주소를 호출) — 틀렸을 경우 비용: 없음(실측 확인).
Ruling: **로그인 계약 전면 정정** — 계획이 추측으로 적은 `POST /api/v1/members/login` + `{email, password}` + 평면 응답은 **전부 틀렸다.** 실제: `POST /api/v1/auth/login`, 요청 `CommandLoginMember{userId, password, memberType(STUDENT|TRAINER, 필수), complimentaryLogin}`, 응답 `ApiResultTokens{status, message, data(Tokens{memberId,name,accessToken,refreshToken,userId,memberType,gymId})}`. Task 5(DTO)·6(signInPath)·9(SignInPage UI '이메일'→'아이디', memberType 파라미터, envelope 파싱)를 전부 수정했다 — 틀렸을 경우 비용: 없음. 그대로 뒀다면 Task 9 패리티 테스트와 런타임 파싱이 모두 실패했을 것.
Ruling: SignInPage에 `memberType = 'STUDENT'` 기본값을 두고 역할 선택 화면은 Phase 1로 미룬다 — 웹은 `/sign-in?type=student` 쿼리로 받지만 Task 9의 목적은 참조 패턴 확립이지 완전한 로그인 플로우가 아니다 — 틀렸을 경우 비용: Phase 1에서 파라미터를 라우터 연결로 바꾸는 작업(작음).
Task 4: re-review — **All 8 findings ADDRESSED, no new Critical/Important breakage.** 재리뷰어가 각 수정에 대해 "결함을 되돌리면 테스트가 실패하는가"를 확인(RED/GREEN 로그 + 뮤테이션 테스트 + 현재 파일 직접 대조).
Task 4: minor (deferred): "예상치 못한 추가 키"의 값이 중첩 맵이면 그 안쪽 비밀은 마스킹되지 않음(최상위 키만 ***). fix 이전보다는 개선됨.
Task 4: minor (deferred): 리스트-of-맵 안쪽 마스킹/비교는 여전히 리프 jsonEncode — Python mask()와 비대칭.
Task 4: minor (deferred): verify.sh가 python3를 하드 요구 — CI에 python3 없으면 파이프라인 정지.
Task 4: complete (commits 22db71a..8e0ce13, review clean after 2 fix rounds)
Task 5: dispatched (opus, BASE 8e0ce13) — 배포 서버 OpenAPI 스냅샷 + 로그인 DTO(실측 계약 반영된 브리프)
Task 5: implementer DONE (commit d43cab2) — verify.sh 4단계 통과, Dart 46 + Python 14. 배포 서버 스냅샷(108 paths, 202 schemas, 597KB)의 로그인 계약이 브리프 Expected와 **완전 일치**해 브리프 코드 수정 불필요.
Task 5: 컨트롤러 자체 점검 — CommandLoginMember ↔ SignInRequest.toJson 키 4개 차집합 없음 ✓, Tokens ↔ SignInResponse.fromJson 키 7개 차집합 없음 ✓, 타입 7개 전부 일치(gymId만 int? nullable) ✓. 스펙의 required는 CommandLoginMember=[memberType]뿐이고 Tokens에는 required 배열 자체가 없음 — implementer가 gymId nullable 근거를 백엔드 Tokens.java의 `gym != null ? gym.getId() : null`에서 가져온 것은 타당.
Ruling: Task 5 리뷰 패키지에서 `openapi/api-docs.json`(14,114줄) 제외 — 전체 diff 618KB 중 대부분이 손으로 편집하지 않는 생성물이라 리뷰어 컨텍스트만 소진한다. 대신 스냅샷에서 관련 스키마 3개만 추출한 계약 발췌(37줄)를 함께 제공했다 — 틀렸을 경우 비용: 리뷰어가 스냅샷 자체의 이상(예: 잘린 JSON)을 못 볼 수 있으나, 컨트롤러가 python으로 파싱해 108 paths/202 schemas를 확인했으므로 무결성은 검증됨.
Task 5: task review dispatched (sonnet, 8e0ce13..d43cab2, 코드만 8KB)
Task 5: review clean — Spec ✅ compliant, quality Approved. Critical 0 / Important 0 / Minor 2. 리뷰어가 implementer의 "브리프 대비 3곳 변경은 계약 무관" 주장을 line-by-line으로 검증해 사실 확인(fixture status는 실제 enum 값, 명시 타입은 strict-raw-types 때문에 필수, 단언 강화는 순증).
Ruling: 리뷰어의 ⚠️(Tokens.java가 gymId 외 필드를 항상 채우는지 확인 필요) **해소** — 컨트롤러가 `backend/src/main/java/com/tobe/healthy/member/domain/Tokens.java`를 직접 읽었다. 7-arg 생성자가 memberId/name/accessToken/refreshToken/userId/memberType을 조건 없이 대입하고, `this.gymId = gym != null ? gym.getId() : null`만 조건부다. implementer 주장이 정확하다. (`@NoArgsConstructor`가 있으나 Jackson 역직렬화용이며 로그인 응답 경로는 7-arg 생성자를 쓴다.) memberId/gymId는 Java `Long` → JSON 정수 → Dart `int`로 호환 — 틀렸을 경우 비용: 백엔드가 나중에 필드를 nullable로 바꾸면 Dart 캐스트가 런타임에 터짐(Minor #1과 같은 지점).
Task 5: minor (deferred): `sign_in_response.dart`의 개별 필드 캐스트가 가드되지 않음 — data는 있는데 개별 키가 없거나 타입이 다르면 진단 가능한 FormatException이 아니라 raw TypeError가 난다. plan-mandated(브리프 코드 그대로).
Task 5: minor (deferred): 스냅샷 대조 테스트가 "login 경로 존재"만 확인 — 백엔드 필드 rename/삭제를 못 잡는다. plan-mandated, 리포트 §7.2에 이미 공개됨.
Task 5: complete (commits 8e0ce13..d43cab2, review clean)
Task 6: dispatched (opus, BASE d43cab2) — dio 클라이언트 + 보안 토큰 저장소 + 인증 인터셉터
Ruling(선제): Task 9 착수 시점에 골든 픽스처가 없으면 — SignInPage 구현·위젯 테스트·팽창률 실측까지 진행하고 **패리티 테스트만 `skip` 사유를 달아 보류**한다. 단 `skip`된 패리티는 "실패를 잡지 못하는 테스트"이므로 **Phase 0 종료 게이트를 통과시키지 않는다** — 골든이 생겨 패리티가 실제로 통과해야 Phase 0 완료로 본다. OpenAPI 스펙으로 골든을 합성하는 대안은 배제: 패리티의 의미는 "웹과 같은 요청"이지 "스펙과 같은 요청"이 아니라서 하네스의 목적을 훼손한다 — 틀렸을 경우 비용: Task 9를 두 번 건드림(작음).
Task 6: implementer DONE_WITH_CONCERNS (commit 081fae9) — verify.sh 4/4, Dart 46→53. flutter_secure_storage 11.1.1 API가 브리프와 일치함을 설치본 소스 직독으로 확인. 변이 2건(토큰 부착 제거 / _isPublic 무력화)으로 테스트가 실제로 죽는 것 확인.
Task 6: **계획 결함 2건을 implementer가 실측으로 교정** — ① 브리프 Step 2의 `RequestInterceptorHandler()..next(options)`는 dio 5.11.1에서 핸들러 Completer를 미리 완료시켜 올바른 구현에서도 StateError로 전부 실패하는 테스트였다(실제 Dio + 가짜 HttpClientAdapter로 교체). ② `_publicPaths`의 `find-id`/`find-password`는 아무것도 매치 못 하는 죽은 문자열이었고 실제 경로는 `/api/v1/auth/find/user-id`·`/find/password`다.
Task 6: 컨트롤러 자체 점검 — OpenAPI 스냅샷 대비 `_publicPaths` 4패턴 전수 검증: `/auth/login`·`/auth/join`·`/auth/refresh-token` 각 1개, `/auth/find/` 2개 매치, **죽은 문자열 0** ✓. `/auth/` 앵커링 덕분에 auth 밖 경로가 잘못 제외되는 오탐 0 ✓. baseUrl 오리진 제약이 dio_client.dart:8-9 주석으로 명시됨 ✓.
Task 6: task review dispatched (opus, d43cab2..081fae9)
Task 6: review — Spec ✅ compliant, quality Approved. Critical 0 / Important 1 / Minor 6. 리뷰어가 implementer의 두 주장을 1차 소스로 독립 검증(dio 5.11.1 `interceptor.dart:99-103`·`:31-38`의 StateError 메커니즘 실재 확인, `@protected` 어노테이션 확인, OpenAPI 108경로 전수로 죽은 문자열 확인).
Ruling: Important #1(미사용 의존성 3개, plan-mandated) — **제거한다.** 브리프 Step 1이 추가를 지시한 건 계획이 Tech Stack 목록을 그대로 Step에 넣은 실수다. Task 7·8 브리프 전제 0건, Task 9의 1건은 해소된 문구, 코드 import 0건. 특히 flutter_riverpod 3.x는 2.x 대비 breaking change인데 검증할 코드 없이 메이저를 고정하는 건 근거 없는 결정이다 — 틀렸을 경우 비용: Phase 1에서 다시 추가(그때 최신 기준으로 평가하는 게 오히려 나음).
Task 6: fix round 1/5 (5 addressed 주장, 재리뷰 대기 — 의존성 3개 제거 / auth/logout→members/logout 교정 / response.data! 가드 / DioClient.create를 테스트가 실제 통과 / 암호화 방식 주석 정정; commits 081fae9..f1c9cc3, Dart 53→60)
Task 6: **Flutter 하한선 원인 규명** — `>=3.44.0`으로 올린 범인은 flutter_secure_storage가 아니라 **go_router 18.0.1**(environment.flutter ">=3.44.0")이었다. 제거 후 **>=3.38.4**로 내려갔고 남은 하한은 path_provider_foundation 2.6.0(flutter_secure_storage 전이 의존) 몫. 본체는 >=3.19.0만 요구.
Task 6: 컨트롤러 자체 점검 — pubspec.yaml에서 riverpod/go_router/mocktail 0건, dio·flutter_secure_storage 유지 ✓. pubspec.lock의 flutter 하한 ">=3.38.4" 확인 ✓. auth_interceptor.dart:18 주석과 test:176이 `/api/v1/members/logout`으로 교정됨 ✓.
Task 6: 변이 검증(implementer) — Fix3 가드 제거 시 `Null check operator used on a null value` 재현, Fix4 DioClient.create의 AuthInterceptor 배선 제거 시 2개 사망(**수정 전이었다면 0개** — 팩토리가 아무것도 안 덮였다는 증명), addAll(extra) 제거 시 1개 사망.
Task 6: re-review dispatched (sonnet, 081fae9..f1c9cc3)
Task 6: re-review — **All 5 findings ADDRESSED, no new Critical/Important breakage.** 재리뷰어가 dio 5.11.1 `sync_transformer.dart:64-76`까지 확인해 "빈 바디+JSON content-type → response=null"임을 검증했고, DioClient.create 뮤테이션 주장(2 사망, 수정 전이면 0)을 테스트 구조로 직접 검증. deferred 2건 미접촉 확인(scope creep 없음).
Task 6: minor (deferred): `flutter pub remove`가 pubspec.yaml의 안내 주석 2줄을 지움 — 기능·구조 영향 없음(cosmetic).
Task 6: minor (deferred): 리포트 산문이 path_provider_foundation을 "linux/windows 전이 의존"이라 기술했으나 실제로는 Darwin(macOS/iOS) federated 구현 — 문서 뉘앙스만, SDK 하한 결론에는 영향 없음.
Task 6: complete (commits d43cab2..f1c9cc3, review clean after 1 fix round)
Task 7: dispatched (sonnet, BASE f1c9cc3) — 공통 위젯 AppButton·AppTextInput (이후 62화면이 복사할 테마 경유 기준)
Task 7: implementer DONE_WITH_CONCERNS (commit b438817) — verify.sh 4/4, Dart 60→66. 브리프의 `find.byType(Container)` 매처를 `AppButton.backgroundKey` 기반으로 교체(위젯 트리 모양이 아닌 배경색 동작 자체를 검증). 컨트롤러가 dispatch에서 허용한 변경이며 이유를 리포트에 기재.
Task 7: 컨트롤러 자체 점검 — **테마 경유 규율 확립 확인.** app_button.dart/app_text_input.dart 양쪽 모두 Color(0x…) 0건, fontSize 직접 0건, circular(숫자) 0건, 각각 AppColors/AppSpacing/AppRadius 3종 경유. 유일하게 잡힌 `EdgeInsets.symmetric(vertical: spacing.s6)`는 리터럴이 아니라 토큰 경유(내 grep이 s6의 숫자를 센 것). `Colors.white`/`Colors.transparent`만 직접 사용하며 코드에 예외 사유가 주석으로 명시됨.
Task 7: 우려(implementer): ① secondary/ghost 변형에 비활성 시각 상태 없음 — 탭 차단은 정상이나 색이 안 변함. 브리프에 값이 정의되지 않아 임의 생성을 거부(웹 디자인에 없는 값을 지어내지 않은 것은 올바른 판단). ② `width: double.infinity`가 폭 제약 없는 부모(Row 등)에서 예외 가능 — 브리프 명세 그대로.
Task 7: task review dispatched (sonnet, f1c9cc3..b438817)
Task 6: (후속 알림) implementer가 SDK 하한선 스캔을 독립 구현(regex vs awk)으로 교차 확인 — 결과 일치. `path_provider_foundation 2.6.0` → `>=3.38.4`가 구속 제약이고 그 아래로 path_provider* `>=3.38.0`, jni* `>=3.35.6`. 이미 기록된 수치와 동일하므로 조치 없음. Task 6 최종 상태 불변(081fae9 + f1c9cc3, verify 4/4, Dart 60 / Python 14).
Task 7: review — Spec ✅ compliant, quality **Needs fixes**. Critical 0 / Important 3 / Minor 3. 리뷰어가 AppColors에 white/transparent 토큰이 없음을 확인해 두 리터럴이 정당한 예외임을 독립 검증했고, AppTypography가 ThemeExtension이 아닌 static const holder라 직접 접근이 우회가 아님도 확인.
Ruling: Important #1·#2는 **계획 결함이며 정답이 웹에 있었다.** 컨트롤러가 웹 원본을 확인: ① `button.tsx:8` base 클래스가 `disabled:bg-gray-300`이라 variant 무관하게 적용되고 `disabled:text-*`가 없어 전경은 variant 기본값 유지 — 즉 계획의 primary 비활성(gray200 배경 + gray400 전경)은 **두 군데 다 틀렸고** secondary/ghost가 안 변하는 것도 틀렸다. ② `SignInForm.tsx:59`가 `border-point focus:border-point`로 테두리를 바꾸고 `:67-69`에서 별도 <p>도 그린다 — 둘 다 한다. 계획 4곳을 웹 실측값으로 수정했다 — 틀렸을 경우 비용: 없음(웹 원본이 근거).
Ruling: Minor #1(`required this.onPressed`, nullable인데 required) **승인** — 호출부가 비활성 의도를 명시하게 강제하는 편이 낫다. 계획 Interfaces를 코드에 맞춰 수정 — 틀렸을 경우 비용: 호출부가 `onPressed: null`을 명시해야 함(의도된 마찰).
Ruling: Important #3(backgroundKey가 static const라 버튼 2개 이상인 화면에서 사용 불가) — `backgroundKeyFor(label)`로 라벨 식별하도록 수정 지시. 이 키가 공개 API이자 복사될 패턴이므로 재사용성 회귀가 맞다.
Task 7: fix round 1/5 (3 addressed 주장, 재리뷰 대기 — 비활성 배경 gray300 통일 / 죽은 errorBorder 제거 후 hasError로 테두리 직접 선택 / backgroundKeyFor 라벨 분리; commit 2a4a70e, Dart 66→72, AppTextInput 테스트 4개 신규)
Task 7: 컨트롤러 자체 점검 — `AppColors.gray300 = Color(0xFFCBCFD3)`이 웹 `gray-300 #cbcfd3`와 **일치** ✓. `errorBorder` 잔존 1건은 코드가 아니라 "왜 이 방식을 쓰지 않았는지" 설명 주석 ✓. `backgroundKeyFor(label)` 적용 확인 ✓.
Task 7: re-review dispatched (sonnet, b438817..2a4a70e)
Task 7: re-review — **All 3 findings ADDRESSED, no new Critical/Important breakage.** 재리뷰어가 각 수정에 대해 revert 시 테스트가 죽는지 확인(gray300이 gray200/gray400과 실제로 구별되는 토큰인지, backgroundKeyFor가 인자를 무시하면 "too many elements"가 나는지, enabledBorder 부재 시 null-check 예외가 나는지).
Task 7: minor (deferred, fix diff가 도입): `app_text_input.dart:70-75`의 `border:` 필드가 `enabledBorder`에 가려져 실질 도달 불가 — 값이 동일해 동작 버그는 없으나 finding #1과 같은 성격의 죽은 분기가 약한 형태로 재도입됐다. **62번 복사되기 전 정리 권고**(border: 제거 또는 고정값). 최종 리뷰에서 triage.
Task 7: minor (deferred, out-of-scope): 비활성 primary가 gray300 배경에 흰 텍스트라 대비가 낮다 — 웹 parity 지시대로이므로 재론 대상 아니나, 향후 시각·접근성 패스에서 확인 필요.
Task 7: minor (deferred, out-of-scope): `backgroundKeyFor(label)`이 라벨만 쓰므로 같은 라벨 버튼이 한 화면에 둘이면(중첩 다이얼로그의 "확인" 등) 다시 충돌한다. 컨트롤러 지시에 내재된 한계이며 Phase 1 이후 이 패턴을 채택하는 태스크가 인지해야 함.
Task 7: complete (commits f1c9cc3..2a4a70e, review clean after 1 fix round)
Task 8: dispatched (sonnet, BASE 2a4a70e) — AppLayout 슬롯 셸. **웹 layout.tsx 직접 대조를 지시**(Task 7에서 브리프 코드가 웹과 두 군데 달랐던 교훈 적용).
Task 8: implementer DONE_WITH_CONCERNS → fix round 1 DONE (commits 54859ea, 9f0153f) — Dart 72→83, Python 14. 웹 layout.tsx 직접 대조로 브리프와 다른 3곳을 교정.
Ruling: **계획 결함 4건이 이 태스크에서 드러났고 전부 웹 실측으로 교정** — ① Contents 기본 패딩: 계획 `s6` → 웹은 패딩 없음(화면별 지정) ② BottomArea: 계획 비대칭 s6/s5/s6/s6 → 웹 `p-7` 균등 ③ Header 배경: `Colors.white` 리터럴 → 테마 참조 ④ **기본 배경: 계획 흰색 → 웹 `layout.tsx:31`이 `bg-gray-100`.** ④는 컨트롤러가 웹을 직접 확인해 `AppLayout(backgroundColor:)` 파라미터 + gray100 기본값으로 지시했다. 웹은 셸이 gray-100을 깔고 화면이 `bg-white`(86곳)/`bg-gray-100`(39곳)으로 덮는 구조 — 틀렸을 경우 비용: 없음(웹 원본이 근거).
Ruling: `AppTheme.light()`의 `scaffoldBackgroundColor`는 **미변경** — 웹에서 배경을 정하는 주체가 전역 body가 아니라 `Layout` 컴포넌트이므로 AppLayout이 명시하는 구조가 구조적으로 일치하고, Task 3 재작업도 피한다 — 틀렸을 경우 비용: AppLayout을 쓰지 않는 화면이 생기면 전역값이 드러남(Phase 1에서 확인).
Ruling: 브리프 스크롤 테스트가 **통과 불가능**했음을 확인 — `SingleChildScrollView`는 자식을 지연 빌드하지 않으므로 드래그 후 `findsNothing`이 성립할 수 없다. 계획 오류이며 검증 방식 교체를 승인한다(Task 6의 dio 핸들러 건과 같은 성격).
Task 8: implementer가 지시받지 않은 실제 결함을 자체 리뷰에서 발견·수정 — `bottomNavigationBar`가 키보드를 자동 회피하지 않음(로그인 화면에서 비밀번호 입력 시 버튼이 가려짐). 회귀 테스트 추가.
Task 8: 컨트롤러 자체 점검 — 웹 `layout.tsx:43-47`의 Header에 배경 클래스가 **없음**을 확인(부모 bg-gray-100을 그대로 드러냄). implementer가 범위를 넘어 AppBar를 `Colors.transparent`로 바꾼 것은 정당하며 코드에 이유가 주석으로 남아 있다. 웹 Header는 `h-[56px] px-7 py-6`.
Task 8: task review dispatched (sonnet, 2a4a70e..9f0153f, 커밋 2개)
Task 8: review — Spec ✅ compliant, quality **Needs fixes**. Critical 0 / Important 2 / Minor 2. 리뷰어가 웹 layout.tsx를 직접 열어 네 곳의 교정을 독립 검증했고 tailwind.config.js의 `7 → 20px` 매핑까지 확인. 스크롤 테스트 불가능 진단과 키보드 회피 결함 진단도 기술적으로 정확하다고 판정.
Task 8: **리뷰가 구현자의 자체 감사를 반증** — 리포트가 "간격: spacing.s7 — 리터럴 없음"이라고 적었으나 `Size.fromHeight(56)`을 놓쳤다. 56은 AppSpacing 12토큰 밖이고 Colors.transparent와 달리 예외 주석도 없었다. 컨트롤러가 "항목마다 확인 방법(grep 등)과 결과를 적어라"고 지시.
Task 8: fix round 2/5 (2 addressed 주장, 재리뷰 대기 — Size.fromHeight(56) → named static const + 웹 h-[56px]도 스케일 밖임을 설명하는 주석 / 헤더·Scaffold 배경 이음매 회귀 테스트 2개(기본값·override) + 뮤테이션 검증; commits e5bf256, b09c9b2, Dart 83→85)
Task 8: **재감사가 추가 결함을 찾음** — `elevation: 0`도 같은 종류의 무주석 리터럴이라 별도 커밋으로 수정. 지시(확인 방법을 남겨라)가 실제로 작동한 사례.
Task 8: re-review dispatched (sonnet, 9f0153f..b09c9b2, 커밋 2개)
Task 9 브리프 재생성 — 계획 4곳 수정(웹 SignInPage 구조 반영) 확인: backgroundColor: Colors.white 1건, _title 분기 2건, horizontal: spacing.s7 1건, '회원 로그인' 2건, '의도적 생략' 절 1건.
Ruling: **Task 9를 웹 SignInPage 구조에 맞춰 계획 수정** — 웹은 ① `<Layout className='bg-white'>`로 셸 기본 배경을 덮고 ② Contents 안에 `px-7`을 화면이 직접 주며 ③ **로그인 버튼이 bottomArea가 아니라 폼 안**(SignInForm의 `mt-[46px]` 블록)에 있고 ④ 제목이 memberType에 따라 '회원 로그인'/'트레이너 로그인'으로 갈린다. 계획은 네 가지가 다 달랐다. 웹에 있으나 Phase 0에서 생략할 것(로고 SVG 자산, 회원가입 outline 버튼, 찾기 링크 — 라우팅·자산 부재)도 계획에 명시해 팽창률 실측 시 생략분이 드러나게 했다 — 틀렸을 경우 비용: 없음(웹 원본이 근거).
Task 8: re-review — **All findings addressed, no new Critical/Important breakage.** 재리뷰어가 주석이 "왜 AppSpacing을 못 쓰는지"를 실제로 설명하는지(상수 이름만 붙인 게 아닌지) 판단했고, 재감사가 항목별 grep 명령·출력을 담아 현재 파일과 일치함을 확인. 이음매 테스트가 간접 프록시가 아니라 `AppBar.backgroundColor` 필드를 직접 단언하는 점도 확인. `elevation: 0` 추가 수정은 정당한 in-scope 확장으로 판정.
Task 8: complete (commits 2a4a70e..b09c9b2, review clean after 2 fix rounds)
Task 9: dispatched (opus, BASE b09c9b2) — 참조 화면 + 팽창률 실측. **골든 픽스처 부재로 패리티 테스트는 skip 보류**, Step 5(실기기)·Step 7(종료 게이트)도 보류 지시. Task 7·8의 실제 시그니처(AppLayout.backgroundColor, AppLayoutHeader.height, AppButton.backgroundKeyFor, onPressed required)를 dispatch에 명시.
Task 9: implementer DONE_WITH_CONCERNS (commit 409fdd4) — verify.sh 4/4, Dart 90 통과 + **2 skip**(패리티), Python 14. 뮤테이션 3건이 각각 의도한 테스트 하나만 떨어뜨림.
Task 9: **팽창률 실측 1.39x** (183/132, 생략 보정 raw↔raw) → 22,257줄 기준 **약 30,900줄**. 대안 측정치: ①1.03x(생략 편향과 주석 편향이 상쇄 — 사용 금지), ④1.05x(code↔code, 코드 밀도). ②와 ④의 차이는 복잡도가 아니라 주석 규율 비용이라는 해석. MOBILE_MIGRATION_ANALYSIS.md §3에 기록 확인(71·86·92줄).
Task 9: **공통 위젯의 웹 불일치 5건 발견(D1~D5) — Task 7·8 유래.** 컨트롤러가 웹 원본과 직접 대조해 전부 실재 확인: Header 제목 `HEADING_4_SEMIBOLD`(18px/w600) vs Flutter `title1`(16px/w700) / 입력 label 색 웹 `gray-800` vs Flutter `gray700` / 버튼 라벨 웹 `TITLE_1_SEMIBOLD`(w600) vs Flutter `title1`(w700) / 버튼 높이 웹 `h-[44px]` vs Flutter ≈54px / 입력 높이 웹 `h-[50px]` vs Flutter ≈54px. **공통 위젯이라 62개 화면에 전파되므로 Phase 1 전 정정 필요.** implementer는 전역 규칙(웹과 다르면 보고만)대로 미수정.
Task 9: 보류 항목 — 패리티 테스트 2개 skip(본문 보존, skip만 떼면 동작 / test/page/sign_in_page_test.dart:120,136), Step 5 실기기 미수행, Step 7 종료 게이트 미수행(6항목 중 4 충족).
Task 9: task review dispatched (opus, b09c9b2..409fdd4) — 팽창률 방법론 검증과 D1~D5의 처리 위치 판단을 함께 요청.

=== 2026-09-14 세션 한도 도달 ===
Task 9 리뷰 dispatch 2회 연속 실패 — HTTP 429 "You've hit your session limit · resets 1:20am (Asia/Seoul)". opus·sonnet 양쪽 동일하므로 모델별이 아닌 **세션 전체 한도**다. 서브에이전트를 더 띄울 수 없어 Task 9 태스크 리뷰와 최종 whole-branch 리뷰를 수행하지 못했다.
Task 9: 컨트롤러 자체 점검(리뷰 대체 아님) — main.dart 보일러플레이트(`Colors.deepPurple`) 제거 확인 ✓(Task 1 deferred minor 자동 해소), baseUrl 오리진만 `https://geonganghaejim.site` ✓, sign_in_page.dart 리터럴 0·테마 경유 3 ✓, 웹 구조 대응(배경 흰색 override·`horizontal: spacing.s7`·폼 안 AppButton·memberType별 제목) ✓.

=== Phase 0 미완료 항목 (다음 세션 인계) ===
1. Task 9 태스크 리뷰 — 미수행(한도). review-b09c9b2..409fdd4.diff 준비돼 있음. 팽창률 방법론 검증과 D1~D5 처리 위치 판단을 함께 요청할 것.
2. 최종 whole-branch 리뷰 — 미수행. MERGE_BASE=d836702. deferred-minors.md(15건)와 D1~D5를 triage 대상으로 넘길 것.
3. **D1~D5 공통 위젯 웹 불일치 수정** — Task 7·8 산출물이 62화면에 전파되므로 Phase 1 전 필수. 컨트롤러가 웹 원본으로 전부 실재 확인함.
4. **HAR 캡처**(사용자) → 골든 생성 → 패리티 skip 2건 해제 → 실제 통과 확인
5. **실기기 확인**(사용자, Task 9 Step 5)
6. Phase 0 종료 게이트(Step 7) — 위 4·5 완료 후에만 의미 있음. 현재 6항목 중 4 충족.
7. 푸시 여부 — 사용자 확인 대기(계획에서 `git push` 제거했고 Phase 0 완료 후 묻기로 함)

=== 2026-09-14 한도 리셋 후 재개 ===
Task 9: task review re-dispatched (opus, b09c9b2..409fdd4) — 세션 한도로 2회 실패했던 리뷰를 재시도.
Task 9: review — Spec ✅ compliant, quality **Needs fixes**. Critical 0 / Important 3 / Minor 4. 리뷰어가 웹 원본과 줄 단위 대조(구조·간격·검증문구), 리터럴 감사 grep 4개 직접 재실행, 생략 45줄 전수 검증(SignInPage 24 + SignInForm 21 = 132 분모 확인)까지 수행.
Ruling: **I2는 컨트롤러의 계획 결함이자 보안 사안** — `kMaskedKeys`에 `userId`가 없다. Task 4에서 목록을 정할 때 로그인 식별자가 `email`인 줄 알았고, Task 5에서 `userId`로 밝혀졌을 때 갱신하지 않았다. 결과 ① 실제 계정 아이디가 평문으로 골든에 커밋되고 ② skip 해제 시 하드코딩 'testuser'와 불일치로 패리티와 무관하게 실패한다. 양쪽 집합에 추가 지시 — 틀렸을 경우 비용: 없음(명백한 보안 개선).
Ruling: **I3 팽창률을 단일값 → 밴드로 변경.** 주석 40줄 vs 2줄로 측정된 팽창의 사실상 전부가 한국어 주석이며, ②를 외삽하면 ~31,500줄 중 ~9,900줄이 주석이 된다(팀이 고르는 문서화 예산이지 마이그레이션 비용이 아님). **1.08x–1.42x → 24,100–31,500줄**로 기록하고 ④를 작업량 proxy, ②를 파일 볼륨으로 라벨링. 리뷰어 지적대로 n=1인데 Task 7/8의 웹↔Dart 쌍 3개가 트리에 있었고 전부 위쪽(1.8x대)을 가리킨다 — 평균 금지·caveat 달아 2차 데이터포인트로 추가. 생략 45줄이 네비·SVG·토스트·브릿지라 외삽이 과소평가 방향이라는 caveat도 기록 — 틀렸을 경우 비용: 밴드가 넓어 계획 불확실성이 남으나, 단일값의 거짓 정밀도보다 정직하다.
Ruling: **D1/D2/D3는 Phase 1 전 수정, D4/D5는 최종 리뷰로 이월.** 리뷰어가 기존 테스트가 틀린 값을 하나도 고정하지 않음을 확인해 토큰 3개 교체가 테스트 변경 없이 가능했다. D4/D5(버튼 h-44px·입력 h-50px vs 패딩 기반 ≈54px)는 한글 폰트 메트릭이 걸린 설계 판단이라 사람이 비교해야 한다 — 틀렸을 경우 비용: D4/D5가 미해결로 남아 시각 확인 시 드러남.
Ruling: **implementer가 제기한 I2↔Minor 모순을 승인.** `userId`를 마스킹하면 userId·password 둘 다 키 존재만 대조되므로 "바꿔 실어도 패리티 통과"라는 원래 주석 주장이 **다시 참**이 된다. 지시를 글자대로 따르면 I2가 만든 상태와 어긋난다. post-I2 기준으로 정확히 재작성하고 결론이 kMaskedKeys 구성에 의존함을 명시한 처리를 승인 — 틀렸을 경우 비용: 없음(논리적으로 정확).
Task 9: fix round 1/5 (6 addressed 주장, 재리뷰 대기 — userId 마스킹 양쪽 추가(Dart만 먼저 고쳐 drift 가드 발화 확인 후 동기화) / 팽창률 밴드 재기록 / 공통 위젯 토큰 3건 + 고정 테스트 3개 / 참고 3쌍 재측정 1.85x·1.86x·1.23x / 주석 근거 post-I2 재작성; commit ae5d4d2, Dart 90→93 + 2 skip)
Task 9: 컨트롤러 자체 점검 — 마스킹 키 Dart/Python 각 10개 차집합 없음, `userId` 양쪽 포함 ✓. 토큰 3건 교정 확인(app_layout:137 heading4SemiBold, app_button:97 title1SemiBold, app_text_input:55 gray800) ✓. MOBILE_MIGRATION_ANALYSIS.md에 옛 수치(1.39x·30,900·183/132) 잔존 없음, 밴드 기록 확인(73·76줄) ✓.
Task 9: re-review dispatched (sonnet, 409fdd4..ae5d4d2)
Task 9: re-review — **All findings addressed, no new Critical/Important breakage.** 재리뷰어가 drift 가드 구현(`har_to_golden_test.py:203-216`이 Dart 파일을 정규식으로 읽어 대조)을 확인해 "Dart만 먼저 고치면 실제로 발화한다"는 주장이 성립함을 검증. 토큰 3건도 AppTypography 정의와 대조해 whole-TextStyle 단언이 revert를 잡는다고 확인. deferred(D4/D5·app_test·D6·로고갭) 미접촉 확인.
Task 9: complete (commits b09c9b2..ae5d4d2, review clean after 1 fix round)

=== 9개 태스크 전부 완료 — 최종 whole-branch 리뷰 단계 ===
최종 리뷰 dispatched (opus, MERGE_BASE d836702..ae5d4d2, 17 커밋 / 113 파일 / ~20,500 insertions).
리뷰 패키지: review-final-code-only.diff (256K, openapi 스냅샷 14,114줄과 폰트 바이너리 제외).
triage 위임: deferred-minors.md 15건 + D4/D5(버튼·입력 고정 높이 vs 패딩 기반). 각 항목에 fix-before-merge / fix-in-Phase-1 / accept 판정을 요구했다.
미완료(리뷰 대상 아님으로 명시): 패리티 skip 2건(HAR 대기), 실기기 확인, Phase 0 종료 게이트.

=== 최종 whole-branch 리뷰 결과 ===
최종 리뷰: **Critical 0 / Important 10 / Minor 11.** Branch verdict — "sound foundation, unusually well-disciplined". 핵심 통찰: **골든 픽스처 형식이 곧 수동 HAR 캡처로 동결되는데 하네스 비교 의미론 3건이 그 형식을 바꾸는 방식으로 틀렸거나 빠져 있다 — 오늘이 마지막 싼 순간.**
최종 리뷰 Important 중 whole-branch 관점에서만 보이는 것: ① 하네스가 헤더를 전혀 비교하지 않고 `writeTokens` 프로덕션 호출부가 0개 → **Authorization 없는 화면이 올바른 화면과 구별 불가**(62화면 인증 검증이 통째로 빔) ② path 리터럴 비교라 `{memberId}` 류 화면이 캡처 계정 id에 묶임 ③ 마스크가 전역이라 `userId`가 모든 엔드포인트에서 검증 불가 ⑥ `--no-fatal-infos`가 모든 린트를 무력화(Flutter 기본은 fatal-infos=true) ⑦ Android Auto Backup + secure storage = 복원 후 BadPadding.
Ruling: **D4/D5 판정을 뒤집는다** — 컨트롤러가 "한글 폰트 메트릭 때문에 사람 판단"이라며 이월했으나 리뷰어가 반박: 같은 Pretendard·같은 타입 스케일이고 16px×1.4=22.4px는 44px에 여유롭게 들어간다. 실제 차이는 **leading 분배**(CSS half-leading vs Flutter ascent/descent 비례)이며 `TextLeadingDistribution.even`으로 코드에서 해결된다. fix-before-merge로 재분류 — 틀렸을 경우 비용: 실기기 시각 대조에서 어긋남이 드러나면 재조정.
deferred 15건 triage 결과: accept 8 / fix-in-Phase-1 4 / **fix-before-merge 3**(리스트-of-맵 재귀, 죽은 `border:`, D4/D5).
최종 fix wave DONE_WITH_CONCERNS (커밋 5개 ae5d4d2→13dc6d9) — A1~A4(헤더 allowlist·리스트 재귀·경로 자리표시자·필터 AND) / B1(`--no-fatal-infos` 제거, 뮤테이션으로 효과 증명) / C1~C4(죽은 border 삭제·고정 높이 44·50+even leading·Semantics·toolbarHeight) / D1(textScaler 상한)·D2(allowBackup=false). **Dart 93→132, Python 14→30.** 뮤테이션 19건 전부 의도한 테스트만 떨어뜨림.
A3 설계: 골든의 `{id}`는 `^\d+$` 세그먼트에만 일치 — OpenAPI 실측(경로 파라미터 64개 중 60개 int64, 나머지 4개는 status·type·notificationCategory 열거형)이 근거. 숫자 전용 규칙이 id와 "값까지 대조돼야 하는 열거형"을 정확히 가른다.
Ruling: **fix가 드러낸 우려 #1(dio가 본문 없는 GET에도 content-type을 붙임)을 캡처 전에 고친다.** 브라우저는 안 붙이므로 골든 대조 시 모든 GET이 실패한다 — 오탐이 아니라 실제 차이. 방향은 "비교를 약화시키지 말고 요청을 고친다": `BaseOptions`의 `contentType` 제거로 dio가 data 있을 때만 붙이게 한다. HTTP 의미론상으로도 본문 없는 요청의 Content-Type은 무의미하다 — 틀렸을 경우 비용: 백엔드가 GET에 content-type을 요구하면 되돌려야 하나, Spring은 통상 무시한다.
Ruling: 우려 #2(쿼리스트링 리소스 id가 값 대조) **Phase 1 이월** — 로그인 플로우에 해당 쿼리가 없어 첫 캡처를 막지 않는다. Phase 1이 목록 화면을 붙일 때 A3과 같은 자리표시자 규칙을 쿼리에 적용한다.
계획 정비(컨트롤러): File Structure 블록을 실제 트리로 교체하고 "Phase 0에 존재하지 않는 것" 절을 신설 — `auth_state.dart`는 단순 rename이 아니라 **실제로 빠진 조각**이며 최종 리뷰 finding #1(토큰 미저장 → 헤더 패리티 무의미)의 근원임을 명시. Phase 1 로드맵 첫 항목을 "auth_state 슬라이스 + writeTokens 배선(최우선)"으로 갱신.
최종 fix 추가 커밋 `7b59c17` — 본문 없는 GET에 content-type 미부착. 가설이 실측대로 맞았다(`BaseOptions.contentType` 제거 시 dio의 `ImplyContentTypeInterceptor`가 data 있을 때만 부착). **기존 패리티·인터셉터 테스트 무파손**(+134 ~2). 뮤테이션 2건: M20 전역 contentType 재도입→GET 테스트 실패, M21 POST에서 data 제거→POST 테스트 실패(단언이 전역 설정이 아니라 data 기반 추론에 의존함을 증명). 지시하지 않았으나 거짓이 된 문서 서술 3곳도 스스로 갱신.
최종 상태: 커밋 23개(d836702..7b59c17), **Dart 134 통과 + 2 skip, Python 30 통과**, verify.sh 4/4, `No issues found!`(플래그 없이), 워킹트리 깨끗.
컨트롤러 자체 점검 7건 전부 통과: verify.sh에 플래그 없음 / BaseOptions에 contentType 미지정(이유 주석) / allowBackup="false" / 입력 height=50 + leadingDistribution 주석 / MediaQuery.withClampedTextScaling / Semantics(+excludeSemantics로 중복 라벨 노드 접음) / toolbarHeight: height.
최종 fix wave re-review dispatched (opus, ae5d4d2..7b59c17, 커밋 6개) — "Ready for HAR Capture?" 판정을 명시 요구했다.

=== 최종 fix wave 재리뷰 결과 ===
**All findings addressed, no new Critical/Important breakage.** A1~A4·B1·C1~C4·D1·D2 + dio content-type 전부 ADDRESSED, "시도함"에 그친 항목 0.
재리뷰어가 1차 소스로 직접 재현한 것: A3 규칙의 과·부족(OpenAPI 경로 파라미터 60 int64 / 4 enum / **108개 경로에 리터럴 숫자 세그먼트 0건** → `^\d+$`가 값 대조 대상을 삼키지 않음), B1 전제(`analyze.dart:118` fatal-infos 기본 true), dio 동작(`interceptor.dart:442` ImplyContentTypeInterceptor 항상 index 0, `imply_content_type.dart:22` data!=null일 때만 추론), C2 잘림 검증(16×1.4=22.4px, 1.3배 29.12px < 44 / 16×1.5=24px, 1.3배 31.2px < 50).
A1의 지시 밖 핵심 추가: `loadGolden`이 `headers` 키 없는 옛 골든을 `StateError`로 거부 — **이게 없으면 A1은 권고에 그친다**는 재리뷰어 평가.

**Ready for HAR Capture? → 형식 동결 가능.** 골든은 HAR에서 스크립트로 생성되므로 이후 규칙 변경(Phase 1의 쿼리 id 자리표시자 등)은 저장된 HAR 재변환으로 해결된다. HAR 자체에 더 많은 정보를 요구하는 항목은 남아 있지 않다.

Ruling: 재리뷰어가 "캡처 전 처리 권고 단 하나"로 꼽은 **HAR 원본 보관 지침**을 반영했다(커밋 `325bd0a`). `.gitignore`에 `har/*` + `!har/README.md`로 실토큰 포함 HAR은 무시하되 보관 이유를 담은 README는 추적한다. HAR을 버리면 재변환 경로가 사라지고 모든 후속 규칙 변경이 사람의 재캡처가 된다 — 이번 동결의 가장 큰 실질 리스크였다 — 틀렸을 경우 비용: 없음(문서·gitignore만).

=== Parked (Phase 1 이월, 전부 Minor — HAR 캡처를 막지 않음) ===
Task: parked — `List<dynamic>` 본문에 content-type 미부착(전역 contentType 제거의 부수효과). dio 추론 조건이 `List<Map>`은 포함하나 `List<dynamic>`은 제외한다. 현 호출부 없음(로그인 POST는 Map)이고 패리티 골든이 차이를 자동 검출한다 — Ruling: 배열 본문 엔드포인트가 생기는 Phase 1+에서 처리.
Task: parked — 생성기가 빈 `headers` 골든을 경고 없이 쓴다. `loadGolden`의 형식 가드는 키 존재만 보므로 통과한다. Chrome DevTools HAR은 항상 request.headers를 담아 실무 위험은 낮으나, 캡처 직후 육안 확인을 절차에 포함했다 — Ruling: 생성기 stderr 경고 한 줄을 Phase 1에서 추가.
Task: parked — C4 가드(제목 세로 중심 단언)가 상수 56에서는 `toolbarHeight:` 삭제를 못 잡는다(kToolbarHeight가 우연히 56). 프로덕션 수정은 들어갔다 — Ruling: `tester.widget<AppBar>(...).toolbarHeight == AppLayoutHeader.height` 한 줄로 Phase 1에서 무조건 가드화.
Task: parked — `--host` 인자 파싱(`sys.argv.index('--host')+1`)이 플래그 순서에 취약. `--path-template` 추가로 오사용 표면이 커졌다 — Ruling: argparse 전환을 Phase 1에서.
Task: parked — `AppTextInput`에 시맨틱 라벨 연결 없음(라벨이 `labelText`가 아니라 형제 Text). C3이 AppButton만 다뤄 두 템플릿 중 하나만 접근성이 채워졌다 — Ruling: Phase 1에서 대칭 처리.
Task: parked — `AuthInterceptor._isPublic`의 부분 문자열 매칭. 경로에 `/auth/login`이 부분 문자열로 포함되는 미래 엔드포인트가 생기면 토큰이 안 붙는다 — Ruling: Phase 1에서 정확 매칭 또는 접두사 앵커링.
Task: parked — D1의 배율 상한 1.3이 접근성 기준으로는 낮다. "웹과 픽셀 동일" vs "OS 배율 존중" 트레이드오프이며 이유가 코드에 있다 — Ruling: Phase 2 이전에 제품 차원에서 의식적으로 재확인.

Ruling: **SDD 워크스페이스를 삭제하지 않는다.** 스킬은 최종 리뷰가 깨끗하면 삭제하라고 하지만, Phase 0은 패리티 skip 2건과 실기기 확인이 남아 **아직 닫히지 않았다.** 이 원장이 Phase 1 인계 문서이며 parked 7건과 Ruling 30여 건의 유일한 기록이다 — 틀렸을 경우 비용: 디스크 수백 KB.

=== Phase 0 최종 상태 (2026-09-14) ===
커밋 24개(d836702..325bd0a) / Dart 134 통과 + 2 skip / Python 30 통과 / verify.sh 4/4 / analyze `No issues found!`(플래그 없이) / 워킹트리 clean / **푸시 안 함**
남은 것: ① HAR 캡처(사용자) → 골든 생성 → skip 2건 해제 → 실제 통과 ② 실기기 확인(사용자) ③ Phase 0 종료 게이트 ④ 푸시 여부 결정

=== HAR 캡처 및 패리티 skip 해제 (2026-09-14) ===
Ruling: **캡처를 사용자 수동 작업에서 컨트롤러 직접 수행으로 되돌린다.** 사용자가 "너가 직접 다시해줘"라고 지시했고, 캡처에 필요한 자격증명이 웹 소스의 공개 상수(`ComplimentaryButton.tsx:8-12`의 체험 계정 상수)라 추측이 아니라 레포에서 읽은 값이다. browser-task 스킬의 "자격증명을 추측·자동입력하지 않는다"는 사용자 개인 계정을 겨냥한 규칙이며, 누구나 누르는 "체험하기" 버튼이 쓰는 데모 계정에는 해당하지 않는다 — 틀렸을 경우 비용: 데모 계정 세션 1건(2시간 만료).
캡처 전 확인한 오염 리스크: 영속 프로필에 이전 체험 로그인 토큰이 남아 로그인 POST에 `authorization`이 붙으면 골든이 오염된다. 웹 소스 확인 결과 `useSignInMutation`이 토큰 없는 `api` 인스턴스를 쓴다(`mutations.ts:70`) — 붙지 않는다. 실제 캡처도 로그인 POST에 `authorization` 없음으로 확인됐다.
캡처 결과(playwright, `/sign-in?type=student` 폼 로그인 → 200 → `/student` 리다이렉트): POST `/api/v1/auth/login` 본문 `{"userId","password","memberType"}` — **`complimentaryLogin` 없음.** referer가 `/sign-in?type=student`로 체험 경로(`/?type=student`)와 구별된다. 후속 GET 3건은 전부 `authorization` 있고 `content-type` 없음 — 헤더 allowlist(A1)와 dio content-type 제거(우려 #1) 두 결정이 실측으로 재확인됐다.
Ruling: **화면 하나에 HAR 하나로 쪼갠다.** 로그인 성공 후 홈이 쏘는 GET 3건을 `login.har`에 함께 담으면 로그인 화면 테스트가 자기가 보내지도 않는 요청 3건을 "누락"으로 잡는다. `har/login.har`(POST 1건) / `har/home-student.har`(GET 3건, Phase 3용) / `har/login-complimentary.har`(체험 경로, 골든 생성 금지)로 분리하고 README에 표로 명시 — 틀렸을 경우 비용: 없음. 골든의 "HAR 재변환으로 규칙 변경 대응" 성질이 그대로 유지된다.
골든 생성: `python3 tool/har_to_golden.py har/login.har login --host geonganghaejim.site --path-template` → 1건. README 체크리스트 충족 — `headers`가 `{"content-type":"application/json"}`로 **비어 있지 않고**, `userId`·`password`가 `***`로 마스킹됐다. `authorization`은 애초에 없다.
skip 2건 해제. 해제 시 거짓이 된 `kGoldenPending` 상수와 "보류 사유" 문서를 지우지 않고 **골든 계약 문서로 다시 썼다** — 조건 6가지(형식·STUDENT·content-type 값 대조·Authorization 부재·마스킹 키·path-template 무관)는 해제 후에도 그대로 유효한 제약이고, 캡처 출처(파일·날짜·폼 로그인)와 웹 소스 위치 2곳을 근거로 덧붙였다.
뮤테이션 검증(M22): `toJson`의 조건부 `complimentaryLogin`을 `?? false`로 항상 포함시키자 패리티 테스트가 `body.complimentaryLogin: 예상치 못한 추가 (실제값 false)`로 정확히 떨어졌다. **골든이 공허하게 통과하는 게 아님을 증명하며, 동시에 체험 경로 HAR을 골든에 쓰면 안 되는 이유를 실행으로 보여준다.** 원복은 문자열 역치환(`git checkout` 금지 규칙).
최종: **Dart 136 통과 + skip 0** (134+2skip에서), Python 30 통과, verify.sh 4/4, analyze `No issues found!`.
남은 것: ① 실기기 확인(사용자) ② Phase 0 종료 게이트 ③ 푸시 여부 결정

=== 시각 게이트(Task 9 Step 5) — 실제 결함 3건 검출 (2026-09-14) ===
Ruling: **시뮬레이터 확인을 컨트롤러가 직접 수행한다.** 계획이 "실제 기기/**시뮬레이터**"를 명시하므로 부팅한 시뮬레이터는 범위 안이다. 다만 계획이 요구하는 "웹 화면을 **나란히 띄우고** 대조"의 최종 판단은 사용자 몫이라, 폰트·세이프에어리어·키보드처럼 스크린샷이 이분법적으로 결정하는 항목만 닫는다 — 틀렸을 경우 비용: 사용자 대조에서 추가 델타가 나오면 그때 반영.
측정 방법: iPhone 17 Pro 시뮬레이터(logical 402x874) 스크린샷과 동일 뷰포트의 웹 스크린샷을 PIL로 **픽셀 열 프로파일** 비교. 눈대중이 처음에 틀린 수를 줬고(버튼 높이를 37pt로 오독), 픽셀 측정이 AppButton 44pt를 정확히 재면서 방법이 검증됐다.
**검출 ① 입력 상자가 24pt다(웹 50).** `SizedBox(height: 50)`이 슬롯만 50으로 잡고, `InputDecorator`는 채움·테두리 상자 높이를 **콘텐츠에서** 계산해 바깥 제약으로 늘리지 않는다(`isDense: true` + 세로 패딩 0 → 상자 = body1 행 높이 24pt, 슬롯 가운데 부유). 기존 테스트 "입력 높이는 웹 h-[50px]와 같다"는 `getSize(TextField)`로 **SizedBox를** 재고 있어 통과했다 — 계획이 경고한 "위젯 테스트는 Flutter가 그린 결과만 검증한다"의 교과서 사례.
**검출 ② 필드 사이 간격이 79pt다(웹 53).** 간격 토큰 `s8`은 맞다. 남은 26pt(50−24)가 위아래 13pt씩 붙은 것이 전부이며 ①을 고치면 함께 사라진다. **토큰을 건드리지 않는다**는 계획의 지시가 그대로 적용된 경우.
**검출 ③ 채움·테두리가 웹과 반대다.** 웹 `TextInput.tsx`는 배경 없음 + `border-gray-200` 1px인데 Flutter는 `fillColor: gray100` + `BorderSide.none`이었다. gray-100은 웹에서 `disabled:bg-gray-100`, 즉 **비활성 상태 색**이다 — 62개 화면이 복사했다면 전 화면의 입력이 비활성처럼 보였을 것이다. gray200 토큰 값(#DEE1E6)은 웹 스크린샷에서 측정한 테두리 색(222,225,230)과 정확히 일치해, 원인이 토큰이 아니라 **조립**임이 확정됐다.
수정: 바깥 SizedBox 제거, 높이를 세로 패딩 `(50 − body1 행높이)/2`로 역산(`expands: true`는 `obscureText`와 동시 사용 불가라 비밀번호 입력에 못 쓴다), `filled: false`, `enabledBorder`를 gray200으로. 테스트 3건 갱신·추가 — 높이 테스트가 이제 SizedBox가 아니라 `InputDecorator`가 계산한 상자를 잰다.
뮤테이션 검증(M23): 세로 패딩을 0으로 되돌리자 높이 테스트가 `Expected: <50.0> Actual: <24.0>`으로 떨어졌다 — **스크린샷에서 잰 24와 테스트가 보고한 24가 같은 수다.** 측정과 단언이 같은 대상을 가리킨다는 증거.
검증: Dart 136 → **137 통과**, Python 30, verify.sh 4/4, analyze `No issues found!`.
**검출 ④ 플레이스홀더가 통째로 없다.** 웹 `SignInForm.tsx:57,83`의 `placeholder='아이디를 입력해주세요.'`에 대응하는 것이 `AppTextInput`에 아예 없었고, 의도적 생략 목록에도 없었다(로고·회원가입·찾기 링크·뒤로가기만 적혀 있었다). `hint` 파라미터 추가 + 웹과 같은 BODY_1/gray-500. **부수 효과:** 웹은 같은 문장을 placeholder와 필수-입력 에러 문구에 함께 쓰므로 빈 입력 시 화면에 같은 글자가 둘이 된다 — 기존 테스트가 `findsOneWidget`으로 깨졌고, 그 테스트의 주석이 정확히 이 상황을 예견해 두고 있었다. `findsNWidgets(2)`로 느슨하게 풀면 유효성 검사가 통째로 빠져도 통과하므로, **point 색으로 에러 텍스트만 집는 finder**를 만들었다. 뮤테이션(M24): 에러 색을 gray500으로 바꾸자 `Found 0 widgets with point 색 에러 텍스트`로 떨어졌다.
폰트 확인(항목 2, 가장 중요): 시스템 폰트 폴백은 **어떤 위젯 테스트도 잡지 못한다**(테스트는 요청한 family 이름만 본다). 스크린샷에서 라벨 글자의 자폭을 재서 대조했다 — '아이디' 웹 34.00pt vs sim 34.67pt, '비밀번호' 47.00pt vs 47.33pt, 높이 양쪽 12.00pt. 폴백이면 수 pt 어긋난다. **Pretendard 렌더 확인.**
키보드 항목(4)을 사람 눈에서 테스트로 옮겼다. 처음 작성한 버전은 `ensureVisible`로 스크롤한 뒤 가시성을 봐서, `SingleChildScrollView`를 통째로 들어내도 통과했다(뮤테이션으로 확인). 이 화면의 버튼을 지키는 것은 스크롤이 아니라 **레이아웃이 키보드 위에서 끝난다는 사실**이라, 스크롤하지 않은 위치를 그대로 재도록 고쳤다. 실측 버튼 아래끝 362pt vs 가시 하한 538pt = 여유 176pt. Phase 2 로고(159pt)를 되살려도 17pt 남아 통과하며, +200에서 562pt로 실패함을 확인했다(M25).
검증: **Dart 140 통과**, Python 30, verify.sh 4/4, analyze `No issues found!`.
미확인으로 남아 있던 `mt-[46px]` → `s12`(48px) 2px 건을 실측으로 닫았다: 입력2 아래끝→버튼 위끝이 Flutter 48.0pt, 웹 46.0pt(버튼 높이는 양쪽 44.0pt로 동일). Ruling: **그대로 둔다.** 웹의 임의값을 글자대로 옮기면 62개 화면의 간격 자리에 리터럴이 흩어져 Phase 0이 세운 토큰 체계가 2px을 위해 무너진다. `h-[50px]`을 상수로 받은 것과 반대 판단인 이유는 그것이 간격이 아니라 **컴포넌트 고유 치수**이기 때문이다 — 틀렸을 경우 비용: 화면당 2px, 디자인 검수에서 지적되면 그때 토큰에 46단을 추가한다.
계획 파일(`docs/superpowers/plans/...`)의 Step 5 시각 5항목과 Step 7 게이트 6항목을 **무엇이 검증했는지 적어서** 체크했다. `docs/`는 git 레포가 아니라 로컬 폴더라 커밋 대상이 아니다. 물리 기기 확인만 미수행으로 남겨 뒀다(시뮬레이터가 재현하지 않는 것: 실제 폰트 힌팅, 터치 타깃 체감, 저사양 성능).
스크린샷 3장을 `screenshots/`에 보관(수정 전/후/웹 레퍼런스) — 원장의 수치가 어디서 나왔는지 추적 가능하게.

=== Phase 0 최종 상태 (2026-09-14, 갱신) ===
커밋 26개(d836702..HEAD) / **Dart 140 통과 + skip 0** / Python 30 통과 / verify.sh 4/4 / analyze `No issues found!`(플래그 없이) / 워킹트리 clean / **푸시 안 함**
종료 게이트 6항목 중 6항목 충족. 남은 것: ① 물리 기기 확인(선택, 시뮬레이터로 대체 검증됨) ② 푸시 여부 결정(사용자)

=== Phase 1 착수 (2026-09-14) — 라우터·자산·인증 상태 ===
사용자 판단: 로그인 화면의 웹 대비 차이 4건(로고·회원가입 버튼·찾기 링크·뒤로가기)을 "한번에" 닫는다. 조사 결과 넷 다 **위젯이 없어서가 아니라 결정 2개(라우터·SVG 자산 파이프라인)가 미결이라** 생긴 것이었다. 특히 뒤로가기는 `AppLayoutHeader.onBack`과 leading 버튼이 이미 있는데 `Navigator.canPop()`이 false라 안 뜬 것 — **돌아갈 홈 화면이 없는 게 진짜 이유**다.
결정: `go_router` ^18.0.1 + `flutter_svg` ^2.3.0. Phase 0에서 go_router를 뺀 이유("Flutter 하한을 3.44로 올린다")는 현재 3.47이라 이미 무효다. 웹이 `/sign-in?type=student`처럼 쿼리파라미터로 화면 상태를 넘기고 73개 라우트가 전부 그 구조라, Navigator named routes로는 부족하다. Phase 3의 푸시 딥링크도 같은 선택을 요구한다.
SVG 확인: 웹 `logo.svg`·`back.svg`에 gradient·filter·mask 0건. `logo.svg`의 `width="current"`는 비표준 값이지만 flutter_svg가 viewBox로 폴백해 파싱된다(프로브 확인). **다만 위젯 테스트의 "파싱됨"은 "보인다"가 아니다** — 자산 누락 SVG는 조용히 빈 박스로 렌더되므로 시뮬레이터 실기 확인 전에는 완료로 치지 않는다.
`AppButton.outline` 추가. 웹 `button.tsx`의 `outline`은 제네릭(`border border-input bg-background`)이지만 실제 호출부가 전부 색을 덮어써서(`border-primary-500 text-primary-500`) **쓰이는 형태**를 담았다. 비활성 시 테두리를 지운다 — 웹은 `disabled:bg-gray-300`이 배경만 덮고 테두리 색은 남아 회색 배경 + 파란 테두리가 되지만, 그 상태를 쓰는 화면이 현재 없다.
색 실측 2건(웹 스크린샷 픽셀):
- 뒤로가기 아이콘 `(0,0,0)` 순수 검정 = SVG `stroke="black"` 그대로. 현재 Flutter는 Material `Icons.arrow_back_ios_new` + gray800이라 자산 교체 시 웹과 일치한다.
- **헤더 제목 `#020817` vs Flutter `gray800 #2E3134` — 신규 델타.** 웹 `<h2>`에 텍스트 색 클래스가 없어 shadcn 기본 foreground를 상속한다. Phase 0의 `app_layout.dart` 주석은 타이포(HEADING_4_SEMIBOLD)만 근거를 댔고 색은 gray800으로 가정했다.
Ruling(외부 리뷰 지적): **패리티 골든이 조용히 낡을 수 있는 지점을 먼저 정한다.** `login.json`이 1건인 것은 로그인 화면이 요청을 1건만 보내기 때문인데, auth_state가 붙고 성공 시 `/student`로 이동하면 홈의 GET 3건이 같은 캡처에 들어와 **올바른 구현이 "예상치 못한 추가"로 실패**한다. 반대로 이동이 캡처 범위 밖에서 일어나면 그 3건은 아예 검증되지 않는다. 경계를 테스트에 명시한다 — SignInPage 패리티는 **로그인 요청까지만** 보고, 홈 GET 3건은 홈 화면이 생길 때 `home-student.har`로 별도 골든을 만든다.
구현 완료(커밋 `63c67e4`). 웹 조사 결과가 전제 두 가지를 정정했다:
- **`/`는 "역할 선택 + 체험하기"가 한 화면이 아니다.** 같은 URL의 두 상태다 — 쿼리 없으면 역할 선택(로고 + 인사말 + 버튼 2개), `?type=`이 붙으면 로그인 수단 선택(뒤로가기 + 제목 + 롤링배너 + 소셜로그인 + 아이디 로그인 + 체험하기 + 고객센터). 버튼이 `<Link href='?type=trainer'>`라 경로는 `/` 그대로다.
- **뒤로가기가 왼쪽에 오는 것은 JSX 순서 때문이 아니다.** `layout-header-title`이 `absolute left-1/2 -translate-x-1/2`라 제목이 flex flow에서 빠지고, 남은 유일한 in-flow 아이템인 버튼이 `justify-between`을 따라 왼쪽 끝으로 간다. `FindIdPage`가 `justify-end`로 같은 메커니즘의 반대 사례를 보여준다 — 추론이 아니라 독립 사례 2건으로 확인.
Ruling: **복원 중 목적지를 `?from=`으로 보존한다.** 기동 직후 스플래시로 리다이렉트하면서 원래 경로를 버리고 있었다(테스트가 잡았다). Phase 3의 푸시 딥링크가 정확히 이 경로로 들어오므로 지금 고치는 게 맞다 — 틀렸을 경우 비용: 없음, 리다이렉트 한 단계 추가뿐.
Ruling: **웹 임의값(`[Npx]`) 규칙을 뒤집는다.** 직전에 `mt-[46px]`를 s12(48)로 스냅하기로 했는데, 로고 블록의 `mt-[40px]`·`mb-[55px]`까지 같은 규칙을 적용하면 이 화면에서만 13px이 누적돼 밀린다. 웹이 스페이싱 클래스를 두고 임의값 문법을 고른 것 자체가 결정이므로 상수로 옮긴다. `AppButton.height`(44)·`AppTextInput.height`(50)·`AppLayoutHeader.height`(56)가 이미 그 규칙이었고, 46만 예외였다 — 판단 규칙이 아니라 기계적 규칙이라 62개 화면에 복사해도 흔들리지 않는다.
Ruling: 체험 계정 상수를 **코드에는 둔다.** har/README.md에서 뺐던 것과 반대로 보이지만 다른 문제다 — 문서는 가리키기만 하면 되고, 이 버튼은 "정해진 데모 계정으로 로그인한다"가 기능 자체라 값을 빼면 기능이 사라진다. 웹도 `ComplimentaryButton.tsx`에 상수로 갖고 있다.
**발견한 Phase 0 결함 2건:** ① `AppButton` 모서리 반경이 8px(웹 `rounded-lg` = `--radius-l` = 12px). 반경을 단언하는 테스트가 하나도 없어 놓쳤다 — 버튼 12 / 입력 8을 각각 고정했다. ② 성공 경로에서 `_isSubmitting`을 되돌리지 않아 이동이 없으면 버튼이 로딩으로 굳었다(테스트가 `pumpAndSettle timed out`으로 잡았다).
두 번째 골든: 보관해 둔 `login-complimentary.har`를 로그인 POST 1건으로 다듬어 `login-complimentary` 골든을 만들었다. 폼 로그인 골든과 **정확히 한 키**(`complimentaryLogin: true`)가 다르고, 양방향 뮤테이션으로 `누락됨`·`예상치 못한 추가`를 모두 확인했다. **HAR 보존 정책이 실제로 값을 돌려준 첫 사례다.**
패리티 경계 명시: 두 화면 테스트 모두 라우터를 끼우지 않는다. 홈이 생기면 성공 후 이동이 GET 3건을 끌고 들어와 올바른 구현이 "예상치 못한 추가"로 실패하기 때문이다. 그 3건은 `home-student.har`로 별도 골든을 만든다 — 테스트 주석에 적었다.
검증: **Dart 164 통과 + skip 0**, Python 30, verify.sh 4/4, analyze `No issues found!`.

=== 최종 리뷰 1순위 지적 종결 (2026-09-14, 커밋 `b1394bc`) ===
"인증 요청이 헤더 없이 나가도 패리티가 통과한다"가 `AuthState`를 만든 뒤에도 **여전히 열려 있었다** — 인터셉터 테스트는 페이크 저장소에 토큰을 손으로 심어 넣고 검사했고, `AuthState`가 그 저장소에 실제로 쓰는지를 잇는 단언은 없었다. 저장소 한 개를 `AuthState`와 `DioClient`가 나눠 쓰게 두고 로그인 응답이 `Authorization` 헤더까지 도달하는지를 재는 테스트를 추가했다.
뮤테이션(M26): `AuthState.signIn`에서 `writeTokens`를 지워 Phase 0 상태를 그대로 재현하자 `Expected: 'Bearer fresh-token' / Actual: <null>`로 떨어졌다. **Phase 0 최종 리뷰가 지적한 그 버그가 이 테스트에 정확히 걸린다.**
함께 고정: 복원 규칙(토큰·프로필 한쪽만 있으면 양쪽을 지운다), 복원 완료 알림(없으면 `refreshListenable`이 안 깨어나 스플래시에서 멈춘다), `AuthUser` 직렬화 왕복 + 깨진 값 처리(앱 버전이 올라가 필드가 바뀌어도 기동이 막히면 안 된다).
검증: **Dart 179 통과 + skip 0**, Python 30, verify.sh 4/4.

=== 아이디·비밀번호 찾기 + 토스트 인프라 (2026-09-14) ===
대상 선정 근거는 `next-screens-survey.md`. 착수 전 외부 리뷰가 지적 4건을 냈고 **전부 웹 소스 실측으로 판정했다.**

**지적 ①「`AppTextInput`이 이 화면에 안 맞을 수 있다」→ 맞았다(치수는), 그러나 다른 버그를 하나 찾았다.**
웹 두 화면은 공용 `TextInput`(62줄)이 아니라 테두리를 `<div>`가 맡고 장식 없는 raw `<input>`(21줄)을 넣는 손수 조립이다. 그래도 치수가 정확히 같다: 랩퍼 `py-[13px]` + BODY_1 행높이(16×1.5=24) + `py-[13px]` = **50px** = `AppTextInput.height`. 라벨 간격(`gap-3`=8px)·`rounded-md`·`border-gray-200`·에러 시 `border-point`까지 일치 → 재사용이 맞다.
**부수 검출: 에러 텍스트 간격이 6px이었다(웹 8px).** 웹은 라벨·입력·에러를 **한 컨테이너의 `gap-y-3`**로 묶어 셋 사이가 전부 8px인데(`SignInForm.tsx`·`FindIdPage.tsx` 둘 다), Flutter만 에러 쪽을 `s2`(6px)로 썼다. 근거 없는 어긋남이고 62개 화면이 복사하기 전에 고쳤다. 테스트는 라벨 쪽 간격과 **같은 값임**을 함께 단언한다 — 한쪽만 바뀌는 회귀를 잡기 위해. 뮤테이션 M27: s3→s2로 되돌리자 실패.
남은 차이 2건은 **의도적으로 공용 컴포넌트 쪽을 따른다**: 에러 문구 굵기(이 두 화면 `BODY_4_MEDIUM` 500 vs 로그인 `BODY_4` 400 — 웹 안에서 이미 갈려 있다. 전체 사용처는 MEDIUM 4 : 일반 2지만, 픽셀 대조를 마친 로그인 화면 쪽을 남긴다), 라벨 색(이 두 화면은 색 클래스가 없어 `#020817`, 로그인은 `text-gray-800`). 둘 다 헤더 제목 색과 같은 "웹이 지정하지 않아서 나온 값" 부류라 같은 결론으로 묶어 디자인 검수 대상에 넣는다.

**지적 ②「비활성 버튼은 전례가 없다」→ 그대로 맞았다.** `AppButton`의 `gray300` 경로를 지금까지 어떤 화면도 쓰지 않았다. 웹 `disabled={!isValid}` + `mode:'onChange'`의 두 성질을 나눠 고정했다 — (a) 첫 페인트부터 비활성, (b) 마지막 필드가 유효해지는 **그 키 입력에서** 활성으로 전환. "유효 입력 → 활성"만 보는 테스트는 버튼이 한 번도 비활성이 아니어도 통과한다. 뮤테이션 M29: `onPressed`를 무조건 `_submit`으로 바꾸자 (a)가 실패.

**지적 ③「토스트는 생김새가 아니라 무엇을 견디는지로 설계하라」→ 웹이 이미 답을 갖고 있었다.**
웹 `useToast()`는 React context가 **아니라 모듈 전역 스토어**다(`memoryState`/`listeners`/`dispatch`). 그래서 언마운트된 컴포넌트가 불러도 토스트가 뜬다. Flutter 대응은 "컨트롤러가 화면보다 오래 산다"이고, 조립 지점(`app.dart`)이 소유해 `MaterialApp.router`의 `builder`에 꽂는다. 호출 규약은 **`await` 앞에서 컨트롤러 참조를 잡는다** — 뒤에서 `read(context)`를 부르면 죽은 컨텍스트를 조회한다. 이 성질을 "화면이 사라진 뒤에 부른 토스트도 뜬다" 테스트로 고정했다.
실측으로 옮긴 웹 값: `TOAST_LIMIT=1`(새 토스트가 이전 것을 밀어냄), `TOAST_DURATION=2000`, `rounded-lg bg-gray-700`, `p-6 pr-8`, 아이콘 `h-8 w-8`(커스텀 스케일 8=**24px**, Tailwind 기본 32가 아니다), `ml-6`=16, `HEADING_5` 흰색, 뷰포트 `p-4`=10px 상단 고정, `ToastDescription`의 `opacity-90`(아이콘까지 90%가 된다).
**설계 결정: 뷰포트에 `IgnorePointer`.** 이 영역은 토스트가 없을 때도 헤더 위를 덮는다 — 없으면 화면 상단의 닫기·뒤로가기가 눌리지 않는다. 웹도 뷰포트는 포인터를 받지 않고 토스트 본체만 `pointer-events-auto`다. 뮤테이션 M30: `ignoring: false`로 바꾸자 탭 통과 테스트가 실패.
`successToast`는 **옮기지 않았다.** 웹 훅에 있지만 부르는 화면이 이 둘 중 하나도 아니고, `check.svg`에 `fill` 오버라이드를 거는 방식을 추측으로 옮기면 검증할 길이 없다.
기존 화면(로그인·온보딩)의 인라인 에러는 **그대로 둔다.** 웹도 그 둘은 인라인(`SignInForm`의 `<p>`), 찾기 화면만 `errorToast`다. "일부는 토스트 일부는 인라인"이 아니라 웹의 구분을 그대로 옮긴 것이다.

**지적 ④「딥링크로 들어오면 `router.back()`이 갈 곳이 없다」→ 맞다. 다만 대체 목적지는 `/sign-in`이 아니다.**
리뷰는 "역할(`?type=`)을 잃지 않도록 로그인 화면으로 보내라"고 했지만, 웹 `/find/id`에는 애초에 쿼리가 없다. 푸시·외부 링크로 콜드 진입하면 **역할 정보가 존재하지 않으므로** 타입 없이 `/sign-in`으로 보내봐야 라우터가 온보딩으로 다시 튕겨 한 단계를 헛돈다. 온보딩(역할 선택)이 정답이다. 반대로 로그인 화면에서 들어온 정상 경로는 `pop`이라 `?type=`이 그대로 살아난다 — 라우터를 끼운 왕복 테스트 3건으로 양쪽을 고정했다.

기타 결정·검출:
- **`automaticallyImplyLeading: false`를 명시했다.** 웹 찾기 화면 헤더는 X 하나뿐인데, `leading`이 null이면 AppBar가 **제 판단으로** 뒤로가기를 끼워 넣는다(스택이 있는 정상 경로가 정확히 그 경우다). 탐침은 `find.byType(BackButton)` — AppBar가 스스로 만드는 위젯 타입이라 우리가 만든 SVG `IconButton`과 구별된다. 뮤테이션 M28: 한 줄 제거하자 왕복 테스트가 실패.
- `serverMessage`를 `core/network`로 승격했다. 이전 라운드에 "세 번째 사용처가 생기면 올린다"고 코드에 적어둔 약속이고, 찾기 2화면이 3·4번째다.
- HAR 캡처를 서브에이전트에 위임했다(브라우저 스냅샷이 메인 컨텍스트를 부풀린다). 입력은 예약 도메인(`홍길동`/`parity-harness@example.com`) — **비밀번호 찾기는 실계정에 대해 비밀번호를 실제로 초기화하므로** 재캡처 시 반드시 지켜야 한다. 두 요청 모두 `authorization` 없음이 실측 확인됐고, `AuthInterceptor._publicPaths`의 `/auth/find/`가 같은 일을 한다.
- 서버 결함 관찰: 존재하지 않는 회원 조회가 **HTTP 404인데 본문 `code`는 "400"**이다. 그래서 상태 코드로 분기하지 않고 `message`만 읽는다(웹도 같다).
- 두 골든의 **본문이 완전히 같다**(`{name, email}`). 경로만 `find/user-id` vs `find/password`라, 골든을 바꿔 쓰면 경로에서 걸린다는 것을 테스트로 직접 넣었다 — 두 로그인 골든과 같은 종류의 "공허하게 통과하지 않는다" 증거.
- `name`은 `kMaskedKeys`에 **없어 값까지 대조된다.** 골든에 `홍길동`이 들어 있고 테스트도 같은 이름을 친다. 재캡처 시 이름이 바뀌면 이 테스트가 먼저 깨진다.
- 소셜 아이콘 자산 4종은 **성질이 두 갈래다**: `naver_logo_circle.svg`(44×45)·`apple_logo.svg`(44×44)는 원형 배경까지 그려진 배지, `google_logo_circle.svg`(22×21)·`kakao_logo_circle.svg`(26×26)는 글리프만. 래퍼 배경은 브랜드 색이라 `AppColors`에 넣지 않고 리터럴로 뒀다.
- 웹은 `socialProviders[socialType]`을 무조건 찾아 써서 모르는 값에 런타임 에러가 난다. 앱은 빈 자리만 남긴다 — 백엔드에 제공자가 추가되면 앱 업데이트 전까지 그 값이 내려올 수 있고, 아이콘 하나가 비는 게 화면 전체가 죽는 것보다 낫다.
- `main.dart`에 `--dart-define=INITIAL_LOCATION`을 열었다. 62개 화면을 옮기는 동안 특정 화면을 실기기에서 보려면 매번 로그인·탭 여러 번을 거쳐야 한다. 컴파일 타임 상수라 define 없는 배포 빌드에는 그 경로가 없다.

**패리티 범위 명시(중요):** 골든이 덮는 것은 **제출 요청 하나씩**뿐이다. 결과 화면 3분기(아이디 카드·편지·소셜)는 실계정 없이 성공 응답을 캡처할 수 없어(예약 도메인 캡처의 응답은 404) **위젯 테스트로만** 고정돼 있다. 특히 소셜 아이콘 4종은 웹 렌더를 본 적이 없다 — 디자인 검수 대상.

검증: **Dart 220 통과 + skip 0**(179 → 220), Python 30, verify.sh 4/4, analyze `No issues found!`. 뮤테이션 4건(M27~M30) 전부 기대대로 실패 확인, 원복은 문자열 역치환.

시각 게이트(시뮬레이터 iPhone 17 Pro, logical 402x874, DPR 3.0) — 스크린샷 2장 `screenshots/06-flutter-find-id.png`, `07-flutter-find-pw.png`.
픽셀 실측: **입력 상자 50.00pt**(지난 라운드 결함 24pt가 재발하지 않았다), 좌우 여백 20.0pt(`p-7`), 버튼 44.0pt(`h-[44px]`), 비활성 배경 gray300. 라벨 간격은 스크린샷에서 13.0/28.0pt로 나오지만 이는 **글자 잉크** 기준이고, TITLE_3 선 상자(14×150%=21pt)의 위아래 여백 4.0/5.0pt를 빼면 8/24pt로 위젯 테스트와 일치한다.
**자산 렌더 위험을 테스트로 닫았다.** 파싱에 실패한 SVG는 예외 없이 **빈 상자로 조용히 렌더**되고 위젯 테스트는 그 상태를 통과시킨다(Phase 1 원장이 경고해 둔 그 구멍). `SvgAssetLoader.loadBytes`를 직접 돌려 렌더 시점의 컴파일을 앞당기는 테스트를 자산 9종에 걸었다. 실측 결과 `love_letter.svg`·`google_logo_circle.svg`에 `clip-path`가 있지만 둘 다 전체 영역 rect(Figma 산물)라 무해하다. 뮤테이션 M31: 없는 경로를 목록에 넣자 실패. 목록을 디렉터리 순회로 만들지 않은 이유는 순회가 "지금 있는 것"만 봐서 **자산 삭제를 못 잡기** 때문이다.
`main.dart`에 `--dart-define=INITIAL_LOCATION`을 연 것이 이 게이트를 가능하게 했다 — 없었으면 찾기 화면 하나 보려고 온보딩→역할→로그인→링크 4탭을 매번 거쳐야 한다.
**여전히 디바이스에서 못 본 것:** 결과 화면 3분기(아이디 카드·`love_letter.svg`·소셜 아이콘 4종)와 토스트. 전부 서버 성공 응답이나 실패 응답이 있어야 뜨는데 시뮬레이터에 텍스트를 자동 입력할 방법이 없다. 자산 파싱은 위 테스트가 닫았고, **배치·색은 미확인**으로 남는다.

=== Phase 1 현재 상태 (2026-09-14) ===
**Dart 229 통과 + skip 0** / Python 30 통과 / verify.sh 4/4 / analyze `No issues found!` / **커밋 안 함(워킹트리에 변경 있음)** / **푸시 안 함**
옮긴 화면: 온보딩(2상태)·로그인·아이디 찾기·비밀번호 찾기. 자리표시자로 남은 것: 회원가입·고객센터·회원 홈·트레이너 홈·헬스장 선택.
남은 것: ① 커밋·푸시 여부 결정(사용자) ② 디자인 검수 3건(헤더 제목 색 `#020817` vs gray800, 입력 에러 문구 굵기 400 vs 500, 입력 라벨 색) ③ 결과 화면·토스트의 디바이스 확인 ④ 다음 화면 선정

=== 착수 후 외부 리뷰 2차 — 키보드 경로 구멍 (2026-09-14) ===
지적: **이 두 화면이 `AppLayout.bottomArea`에 상호작용 컨트롤을 넣은 첫 화면이다.** 로그인 화면의 제출 버튼은 `contents` 안이라 기존 키보드 테스트가 재는 것은 Scaffold의 **body** 경로이고, `bottomNavigationBar`는 `_ScaffoldLayout`이 `size.height` 기준으로 자리를 잡아 규칙이 완전히 다르다. `AppLayout`이 `viewInsets.bottom`을 패딩으로 직접 더해 보정하는데, 그 보정이 **일하는지 이중 계산인지** 가르는 테스트가 없었다(`app_layout_test.dart`의 3건은 키보드를 열지 않는다).
주입 방법: `MaterialApp`이 뷰로부터 자기 `MediaQuery`를 만들어 바깥 것을 덮으므로 **안쪽**(`home:` 아래 Builder)에서 `viewInsets`를 덮어써야 한다. 표면도 기본 800x600이 아니라 실기기와 같은 402x874로 맞췄다 — 600pt에서는 키보드를 띄우면 본문이 160pt만 남아 "필드가 보이는가"가 화면 크기 탓인지 버그 탓인지 구분되지 않는다.
**뮤테이션 M32 결과: 보정은 실제로 일한다.** `+ EdgeInsets.only(bottom: keyboardInset)`을 지우자 `버튼 아래끝 854.0 vs 가시 하한 574.0` — 키보드 뒤로 280pt 완전히 숨는다. 이제 고정됐다. 둘째 입력(사용자가 마지막으로 치는 필드)의 가시성도 함께 단언한다.
리뷰가 자기 지적 하나를 철회했다: 딥링크 `_close` 대체 목적지를 `/sign-in?type=`으로 하라던 것 — 웹 `/find/id`에 애초에 쿼리가 없어 콜드 진입에는 보존할 역할이 없다는 실측이 맞다.
`serverMessage` 승격 중 **동작이 하나 바뀐 것을 발견해 테스트로 고정했다.** 원래 private 헬퍼는 서버가 `message: ''`를 주면 `''`를 그대로 돌려줬고, 로그인 화면은 그걸로 **빈 에러 Text**를 그렸다(문구 없이 s6 간격만 생긴다). 토스트였다면 빈 검은 막대가 된다. `isNotEmpty` 조건을 붙여 null로 떨어뜨리고 호출부의 '문제가 발생했습니다.'를 쓰게 했다 — "순수 이동"에 섞인 의도적 수정이라 여기 남긴다. 상태 코드로 분기하지 않는다는 결정(HTTP 404 vs 본문 code "400")도 같은 파일에 고정했다.
최종: **Dart 238 통과 + skip 0**(229 → 238), Python 30, verify.sh 4/4, analyze `No issues found!`.

---

## 2026-09-15 — `/select-gym` 이관 (웹 라우트 5/73)

브랜치 `feature/select-gym`. 사용자 승인 설계는 `docs/select-gym-brief.md`.

**웹 실측이 뒤집은 가정 둘.**
① `AppButton.height = 44`는 컴포넌트 고유 치수가 아니라 **로그인 화면이 고른 값**이었다. 웹 전체 분포는 `h-[48px]` 25회 · `h-[57px]` 9회 · `h-[44px]` 5회이고 `/select-gym`은 57이다. 타이포도 갈린다(`TITLE_1_BOLD` 77회 vs `TITLE_1_SEMIBOLD` 84회). 고정해 두면 62개 화면이 전부 로그인 화면의 치수를 물려받으므로 `height`·`labelStyle`을 열었다 — 색과 half-leading 보정은 컴포넌트가 계속 책임진다(화면에 맡기면 하나만 빠뜨려도 그 화면만 1~2px 어긋난다). 상수는 `AppButton.defaultHeight`로 개명.
② 웹 `(login-required)` 그룹에는 **`layout.tsx`가 없다.** 그룹 이름과 달리 실제로 막는 것이 아무것도 없고, 미로그인으로 `/select-gym`을 열면 토큰 없는 요청이 나간다(웹 쪽 결함). 앱은 이 화면이 `auth.user!.memberType`으로 제목을 갈라 그대로 두면 null 역참조로 죽으므로, **웹에 없는 게이트를 명시적 이탈로 추가**했다.

**`context.go`가 없으면 화면이 넘어가지 않는다 (M1로 확인).** `_redirect`를 `/select-gym` 위치에서 돌리면 splash 아님 → signIn 아님 → `isHome` false → 모든 가드 통과 → `null`(현재 위치 유지)이다. `AuthState.setGymId`의 `notifyListeners()`가 `refreshListenable`을 깨워도 재평가 결과가 "그대로 있어라"라서 아무 일도 일어나지 않는다. 웹도 `router.push(...)`로 직접 이동한다. 뮤테이션으로 `context.go`를 지우니 이동 테스트 3건이 함께 깨졌다.

**`pumpAndSettle`이 경합 테스트를 조용히 무력화한다 (M2가 알려준 것).** "프로필 저장 → 이동" 순서를 뒤집는 뮤테이션을 넣었는데 **테스트가 그대로 통과했다.** 원인은 `pumpAndSettle`이 기본 100ms씩 시간을 진행시킨다는 것 — 50ms 지연 저장소로 만든 경합 창이 첫 pump 한 번에 통째로 삼켜졌다. 2초로 늘리자 비로소 잡혔다(뒤집으면 `/student` 진입 시 `gymId == null`이라 `/select-gym`으로 되튕긴다). **가드를 넣고 뮤테이션이 안 잡히면 가드가 아니라 테스트 하네스를 먼저 의심할 것.** `next-steps.md` 규율 #11로 올렸다.

**`AuthState`에 `gymId` 갱신 경로가 처음 생겼다.** 기존 mutator는 `signIn`/`signOut` 둘뿐이었다. `setGymId(int)`는 프로필 저장이 **끝난 뒤** 알린다. `AuthUser`에는 범용 `copyWith` 대신 `withGymId`만 열었다 — 아무 필드나 갈아끼울 수 있으면 `memberType`을 화면에서 바꾸는 코드가 생기고, 그 순간 라우팅 근거가 서버가 아니라 화면이 된다.

**웹의 비대칭을 그대로 옮겼다.** `clickNext`는 `authValue`를 리셋하지만 `clickBack`은 `selectGymId`를 리셋하지 않는다. 그래서 인증 코드 단계에서 뒤로 오면 고른 헬스장이 남아 다음 버튼이 활성이다. 둘 다 테스트로 고정.

**STUDENT POST는 바디가 없다.** 웹 axios는 `data === undefined`면 Content-Type을 붙이지 않는다. `registerGym`이 `{}` 대신 `null`을 넘겨야 같아지며, 이 성질의 전제는 Phase 0이 `DioClient.create`에서 전역 `contentType`을 일부러 지정하지 않은 것이다. 뮤테이션(`null` → `{}`)으로 두 단언이 함께 깨지는 것을 확인했다.

**`AppOtpInput`은 입력 하나 + 슬롯 6개다.** 웹 `input-otp`와 같은 구조 — `TextField` 6개로 만들면 붙여넣기와 슬롯 경계 backspace가 달라진다. 테스트에서 `find.text`가 **숨은 입력의 값까지 잡는다**(같은 문자열이 두 곳에 산다)는 점에 걸려, 슬롯 안으로 범위를 좁히는 헬퍼를 뒀다.

**명시적 이탈 1건(디자인).** 웹 로딩은 `/images/loading.gif` 20×20이다. 자산을 가져오지 않고 `CircularProgressIndicator`로 대체했다 — 애니메이션 자산은 `assets_test.dart` 목록 관리를 늘리는데 정작 움직임을 검증할 수단이 없다(규율 #8: "파싱됨"은 "보인다"가 아니다).

**미완:** 패리티 골든 `select-gym`(GET 1건)이 아직 없다. 캡처를 마지막으로 미뤘다(사용자 결정). 절차와 주의는 `har/README.md`에 적어 뒀다. 등록 POST는 공유 상태 뮤테이션이라 골든을 만들지 않고 계약 테스트로 간다.

**리뷰가 제기한 OTP 키보드 문제는 반대 결론이었다.** "`TextInputType.number`가 웹과 다르다"는 지적을 받고 양쪽을 실측했더니, 웹 `input-otp`의 `inputMode` **기본값이 `'numeric'`**이라 웹도 숫자 키패드를 띄운다(패키지 문서). 동시에 웹은 `pattern`을 주지 않아 문자 자체는 거르지 않는다. 백엔드도 `RandomStringUtils.randomNumeric(6)`으로 숫자 6자리를 만든다. 즉 "숫자 키보드 + 문자 필터 없음"이 패리티다. **틀린 것은 구현이 아니라 주석이었다** — 근거 없이 "숫자 키보드는 편의"라고 적어 임의 선택처럼 읽혔다. 근거를 넣고 두 성질을 짝으로 묶는 테스트를 추가했다(한쪽만 보고 필터를 넣는 "일관성 있는" 수정을 막는다).

덤으로 확인된 것: **서버는 joinCode의 길이·문자 종류를 전혀 검증하지 않는다.** `CommandSelectMyGym`에 Bean Validation이 없고 컨트롤러에 `@Valid`도 없어 저장값과 문자열 동등 비교만 한다. 형식 제약을 서버에 기대면 안 된다.

**골든 첨부(같은 날 이어서).** playwright로 체험 계정 세션에서 `/select-gym`을 열어 `GET /api/v1/gyms` 1건을 캡처했다. **등록 버튼은 누르지 않았다** — POST가 그 계정의 소속 헬스장을 실제로 바꾼다. 실측으로 확인된 것 둘: ① 요청에 `authorization`이 붙는다(웹 `authApi`), ② **`content-type`이 없다** — 본문 없는 GET이라 브라우저가 붙이지 않으며, Phase 0이 `DioClient.create`에서 전역 `contentType`을 지정하지 않은 결정이 여기서 값을 한다.

HAR의 `authorization` 값은 캡처 시점에 지웠다. 변환기가 이 헤더를 presence-only로 `***` 마스킹하므로 실토큰이 있든 없든 생성되는 골든이 같다 — `har/README.md`에 명시했다(다른 HAR은 실토큰을 품고 있어 gitignore는 그대로다).

**골든이 공허하지 않은지 뮤테이션 2건으로 확인했다.** M5(경로를 `/api/v1/gym`으로) → `path: 기대 /api/v1/gyms, 실제 /api/v1/gym (세그먼트 [3]: 'gyms' vs 'gym')`, M6(`/gyms`를 `_publicPaths`에 넣어 토큰 탈락) → `headers.authorization: 누락됨`. 둘 다 진단이 정확했다.

최종: **Dart 292 통과**(238 → 292, +54), Python 30, `verify.sh` 4/4, analyze `No issues found!`. 뮤테이션 M1~M6 전부 기대대로 실패 확인.

---

## 2026-09-15 — `/policy` 허브 + `/sign-up/complete` (웹 라우트 7/73)

"싼 화면 먼저"로 고른 4개 묶음인데, **실측이 전제를 절반 뒤집었다.** `/policy`(47줄)와 `/sign-up/complete`(55줄)는 정말 쌌지만 약관 2개는 아니었다 — 코드 줄 수(336·154)가 아니라 **본문 15,000자 + `<li>` 157개 + 2단계 중첩 리스트**가 본체이고, `.policy-container` CSS를 옮기면 사실상 약관 문서 렌더러를 새로 만드는 일이다. 전체 공수의 70%가 거기 있다. 본문 형식(Dart 위젯 직역 / Markdown 에셋 / 원격 fetch)을 정해야 하는 갈림길이라 **자리표시자로 남기고 둘만 옮겼다.** 실측은 `docs/policy-screens-survey.md`.

**`AppLayout`의 본문에서 `Expanded`를 쓸 수 없다는 것을 여기서 처음 부딪혔다.** 웹 `SignUpCompletePage`는 바깥 div가 `justify-between`, 안쪽 div가 `h-full justify-center`다. 안쪽을 `Expanded`로 옮겼더니 `RenderFlex children have non-zero flex but incoming height constraints are unbounded`로 터졌다 — 셸이 본문을 `SingleChildScrollView`로 감싸기 때문이다(그 `ConstrainedBox(minHeight:)`는 최소 높이만 보장하지 최대를 묶지 않는다). **높이 0짜리 자식을 맨 위에 두고 `spaceBetween`**으로 재현했다: 자식이 셋이면 남는 공간이 두 등분되어 가운데 블록 위아래 간격이 같아지고, 결과 위치가 웹의 "버튼 위 영역에서 가운데"와 정확히 일치한다. 62개 화면이 반복해서 만날 문제라 규율 #12로 올렸다.

**화살표 자산의 색 override는 no-op이었다.** 웹 `PolicyPage`가 `IconArrowRightSmall`에 `stroke={'var(--gray-400)'}`를 넘기는데, 자산 자체가 이미 `stroke="#A7A9AE"`이고 `--gray-400: #a7a9ae`다 — 같은 값이다. 그래서 Flutter에서는 색을 덮지 않고 `back.svg`·`close.svg`와 같이 그대로 쓴다.

**가입완료의 파라미터 누락 처리를 라우터로 올렸다(명시적 이탈).** 웹은 화면 안에서 `if (!type || !name) throw new Error()`로 **인자 없는** 에러를 던져 `app/error.tsx`에 떨어진다. 앱에서 크래시는 부적절하므로 `/sign-in`의 `?type=` 게이트와 같은 자리에서 온보딩으로 돌려보낸다. 뮤테이션 M7(name 게이트 제거)로 확인했다.

**이 둘은 지금 앱에서 도달 불가다.** `/policy`의 유일한 인바운드는 마이페이지(미구현), `/sign-up/complete`는 `/sign-up`(자리표시자)이다. 선행 작업으로만 의미가 있고 확인은 `--dart-define=INITIAL_LOCATION=/policy`로 한다. 요청이 0건이라 **패리티 골든이 없다** — 하네스를 빠뜨린 게 아니라 대조할 요청 자체가 없는 경우다.

**웹 쪽 버그 1건 발견(미수정).** `frontend/src/page/public/ui/PolicyTermsPage.tsx:313`에 `<h3></h3>` 빈 제목이 있다. 제23조와 제25조 사이, 내용은 분쟁해결 — `제 24조 [분쟁해결]`이 누락됐고 현재 웹은 조항 번호 없이 렌더 중이다. 약관 본문을 옮길 때 원본 문서와 대조해 채우고 **웹도 함께 고쳐야 한다.**

최종: **Dart 316 통과**(292 → 316, +24), Python 30, `verify.sh` 4/4, analyze `No issues found!`. 뮤테이션 M7·M8 기대대로 실패 확인.

---

## 2026-09-15 — `/student` 홈 Phase A (웹 라우트 8/73)

사용자 승인 설계는 `docs/student-home-brief.md`. Phase A = 진입 렌더 + GET 3건,
Phase B = FCM · S3 업로드 · 식단 시트 · 401 리프레시.

**실측이 Phase 경계를 바꿨다.** 처음에는 하단 네비를 Phase B로 미뤘는데,
골든 3건 중 `GET /api/v1/members/trainer-mapping`이 **홈이 아니라 네비가 쏘는
요청**이었다(웹 `useCheckTrainerMemberMappingQuery`에 `enabled` 옵션이 없어
마운트 즉시 나간다). 네비 없이 만들면 요청이 2건이라 `expectParity`가 떨어진다.
**골든이 이 선택을 이미 닫아놨다.** 뮤테이션 M11(네비 제거)로 확인 —
`요청 개수 불일치: 기대 3건, 실제 2건`.

**요청 순서를 웹의 메커니즘이 아니라 골든으로 맞췄다.** 웹에서
`trainer-mapping`이 첫 번째인 이유는 React effect가 **자식부터** 실행되기
때문인데(네비가 자식), Flutter `initState`는 부모가 먼저다. 그대로 두면
`home/student` → `red-dot` → `trainer-mapping`이 된다. 화면이 자기 요청 둘을
`addPostFrameCallback`으로 미뤄 순서를 고정했다 — 웹의 effect 순서를 재현하려는
것이 아니라 **골든 순서를 요구사항으로 받은** 것이다. 뮤테이션 M10(postFrame
제거)이 순서 단언과 패리티를 함께 깨뜨린다.

**`fill="current"`는 flutter_svg에서 아이콘을 통째로 지운다.** 웹에서 가져온
자산 넷(`check`·`plus`·`arrow_filled_up`·`arrow_filled_down`)이 유효하지 않은
`fill="current"`를 쓴다. 브라우저는 **유효하지 않은 표현 속성을 무시하고 부모
값을 상속**해서 SVGR 컴포넌트에 넘긴 `fill` prop 색이 내려오는데, flutter_svg는
"칠하지 않음"으로 처리한다. 픽셀 프로브로 실측했더니 `arrow_filled_up`은
**한 픽셀도 그려지지 않았고**(`NOTHING DRAWN`) `check`는 5픽셀이었다.
`assets_test.dart`의 기존 컴파일 테스트는 이 상태를 **그대로 통과시킨다** —
규율 #8("파싱됨"은 "보인다"가 아니다)의 교과서적 사례다.

표준 `currentColor`로 정규화하고 화면이 `SvgTheme(currentColor:)`로 색을
주입한다(웹이 prop으로 하던 일과 같다). `check.svg`의 `stroke="current"`는
제거했다 — 브라우저에서 그 속성은 무시되고 루트에 stroke가 없어 `none`으로
해석된다. **자산을 다시 그린 것이 아니라 브라우저가 실제로 하는 해석을 명시한
것이다.** 두 색으로 각각 렌더해 픽셀을 세는 회귀 테스트를 추가했고, 뮤테이션
M9(`currentColor` → `current`)에서 `Actual: <0>`으로 정확히 잡힌다.
`width="current"`·`height="current"`는 **건드리지 않았다** — `arrow_down`·
`avatar`·`logo`가 그 상태로 이미 올바르게 렌더된다(프로브 확인).

**`intl`을 도입했고 초기화를 `main()`이 아니라 조립 지점에 뒀다.** 예약 카드가
`MM.dd (E)`·`a hh:mm`을 ko 로케일로 쓴다(서버가 포맷해 주는 `lessonHistory`와
달리 `myReservation`은 원시 `LocalDate`/`LocalTime`이다). `main()`에만 두면
`GeonganghaejimApp`을 직접 만드는 테스트와 딥링크 진입이 초기화 없이 돌고,
`intl`은 로케일 데이터가 없으면 던진다 — **예약이 있는 계정에서만 홈이 죽는**
종류의 실패다. 라우터·dio와 같은 이유로 `app.dart`가 소유한다.

**웹 타입이 계약과 다르다.** `HomeDataResponse`는 일곱 필드를 전부
non-optional로 선언하는데 소비 측은 네 필드를 전부 런타임 가드한다
(`{data?.course && ...}` 등). 서버가 null을 준다는 뜻이고, 그대로 Dart로
옮겼다면 null 역참조가 났다. 여덟 필드 전부 nullable로 받는다 — 웹이
`point`·`rank`·`gym`을 가드 없이 쓰는 것은 웹의 운이지 계약이 아니다.
`lessonHistory.files`도 웹은 단수 객체로 선언했지만 백엔드는 `List`다.

**웹 버그 2건을 버그째 옮겼다(사용자 결정).** ① 월 표시
(`searchDate.split('-')[1].split('')[1]`)가 10~12월에 "0월/1월/2월"이 된다.
② 포인트·랭킹이 `{data?.course && ...}` 안쪽에 중첩돼 수강권이 없으면
통째로 사라진다. **둘 다 잘못된 결과를 단언으로 고정**했다 — 나중에 누군가
조용히 "개선"하면 테스트가 먼저 깨져서 결정을 다시 보게 된다. 근거와 수정
지침은 `deferred-minors.md`.

**웹의 이중 상태를 하나로 합쳤다.** 웹은 포인트 펼침을 `isOpen` useState와
Radix Collapsible 내부 상태 **두 군데**로 관리한다(같은 클릭으로 함께 움직여
버그는 아니다). Flutter `AppCollapsible`은 controlled로 만들어 bool 하나다.

**레이아웃에서 두 번 걸렸다.** ① 포인트 상세의 두 카드가 웹에서 `h-full`로
높이가 같아지는데(flex 기본 stretch), Flutter `CrossAxisAlignment.stretch`는
부모 높이가 무한이면 `BoxConstraints forces an infinite height`로 터진다 —
`IntrinsicHeight`로 감쌌다(규율 #12와 같은 뿌리). ② `w-[130px]` 카드 안에서
아이콘 21px + "이번달 포인트"가 내용 폭 98px를 넘긴다. 웹은 flex 자식이라
줄바꿈되지만 Flutter는 `RenderFlex overflowed`다 — `Flexible`로 같게 맞췄다.

**라우트를 10개 추가했다**(브리프에는 3개로 적었다). 하단 네비 3개 외에
헤더·카드에서 나가는 경로가 더 있다(`alarm`·`course-history`·`point-history`·
`log`·`log/:id`·`diet`·`workout`). go_router는 등록되지 않은 경로로 `go`하면
에러 화면을 띄우므로, 빠뜨리면 **카드를 누르는 순간 앱이 에러 화면으로 빠진다.**

**`app_test`의 착지 표식을 바꿔야 했다.** `/student`가 자리표시자였을 때는
제목 '회원 홈'으로 도착을 확인했는데 그 제목이 사라졌다. 응답 내용과 무관하게
늘 그려지는 "개인 운동 기록" 카드 제목으로 바꿨다(웹도 이 카드만 조건 없이
렌더한다). 7곳.

**폰 너비 테스트가 실배포될 버그를 잡았다.** 위젯 테스트 기본 뷰포트는
800×600인데 **실기기는 논리 폭 ~390**이다. 오버플로는 좁은 쪽에서 사는데
거기를 한 번도 안 보고 있었다 — 390pt로 바꿔 펌프하자 예약 카드의
`09.15 (화) 오후 02:30`(18px bold)이 **35px 넘쳤다.** `_PointTitle`과 같은
종류(웹은 flex 자식이라 줄바꿈, Flutter Row는 넘침)라 `Flexible`로 고쳤다.
`/student`는 로그인 게이트 뒤라 `INITIAL_LOCATION`만으로 실기기에서 열 수
없으므로(규율 #9), 폰 너비 테스트 4건이 그 자리를 대신한다 — 만료 분기와
긴 헬스장 이름까지 함께 본다.

**red-dot이 홈 응답을 기다리고 있었다.** `await _loadHome(); await
_loadRedDot();`이라 홈이 끝나야 red-dot이 시작돼, 느린 네트워크에서 헤더
빨간 점이 웹보다 늦게 뜬다(웹은 effect 둘이 같은 틱에 나간다). 개시 순서는
유지한 채 `Future.wait`로 함께 기다리게 바꿨다. 원래 주석이 적은 근거
("`Future.wait`는 실패 하나가 둘을 무너뜨린다")는 **성립하지 않았다** —
두 메서드가 각자 안에서 try/catch로 삼키므로 던지는 쪽이 없다. 골든·순서
단언은 개시 순서만 보므로 그대로 통과한다.

최종: **Dart 420 통과**(316 → 420, +104), Python 30, `verify.sh` 4/4,
analyze `No issues found!`. 뮤테이션 M9·M10·M11·M12 전부 기대대로 실패 확인.
골든 `home-student`가 **드디어 소비된다** — `next-steps.md` §6의 이월 부채가
여기서 닫혔다.

---

## 2026-09-15 — `/trainer` 홈 Phase A (웹 라우트 9/73)

사용자 승인 설계는 `docs/trainer-home-brief.md`. **로그인이 착지하던
자리표시자 셋이 여기서 전부 닫혔다**(`/select-gym` → `/student` → `/trainer`).

**골든을 먼저 떴고, 그게 설계를 바로잡았다.** 학생 홈에서 "골든이 Phase
경계를 정한다"를 배운 대로 캡처를 앞당겼는데, 트레이너 골든은 학생과
**모양이 달랐다**: 1번이 `members/trainer-mapping`이 아니라 `members/me`다.
`TrainerNavigation`에는 react-query 훅이 하나도 없어(가드가 없고 탭 넷이 전부
`<Link>`다) **네비가 요청을 쏘지 않는다** — 세 건 전부 페이지가 쏜다.
그래서 학생 홈이 순서를 맞추려고 쓴 `addPostFrameCallback`이 여기서는
필요 없었다. 두 홈을 같은 모양으로 가정했다면 헛수고를 했을 것이다.

`members/me`는 **헤더의 헬스장 이름 하나** 때문에 붙는 왕복이다. 백엔드
`TrainerHomeResult`에도 `gym`이 있어 요청 하나를 아낄 수 있어 보이지만,
줄이면 골든이 3건에서 2건이 되어 패리티가 깨진다(뮤테이션 M13으로 확인).

**캡처 절차에서 걸린 것.** playwright 영속 프로필에 학생 세션이 남아 있어
루트가 곧바로 `/student`로 리다이렉트됐다. 사이트의 `localStorage`를 비우고
트레이너 "체험하기"로 다시 들어가야 한다 — `har/README.md`에 적었다.
트레이너 체험 계정은 `gymId=1`이라 `/select-gym`으로 튕기지 않는다.

**BUG-1을 백엔드 소스로 확정했다.** 서베이는 `lessonStartTime`의 형식을
"미확인"으로 남겼는데, 백엔드 `LessonDetailResult.lessonStartTime`이
`LocalTime`이라 `"09:00:00"`으로 직렬화된다. dayjs의 `REGEX_PARSE`는 4자리
연도로 시작해야 매치되므로 네이티브 `Date`로 폴백해 **Invalid Date**가 되고,
그 결과 `findClosestSchedule`의 비교가 전부 false가 되어 **"가장 가까운
수업"이 언제나 배열의 첫 원소**가 된다. 직역해서 옮기고 테스트로 고정했다.

**뮤테이션이 테스트의 구멍을 찾아냈다.** M14(하이라이트를 실제 시각순으로
정렬)를 넣었더니 모델 테스트는 잡았는데 **페이지 테스트는 통과했다** —
"하이라이트가 하나뿐"만 단언하고 **어느 카드인지**를 안 봤기 때문이다.
픽스처를 23:00(첫째)·08:00(둘째)로 두고 "23:00이 칠해지고 08:00은 아니다"로
바꾸자 비로소 잡혔다. **가드를 넣었는데 뮤테이션이 안 잡히면 가드가 아니라
테스트를 먼저 의심하라**(규율 #11과 같은 교훈).

**네비를 표현/동작으로 갈랐다.** 웹은 `StudentNavigation`·`TrainerNavigation`이
별개 컴포넌트인데 껍데기 마크업이 문자열까지 같다. 공통부를
`AppNavigationBar`로 빼고 두 네비가 각자의 동작만 갖게 했다. 학생 네비는
마운트 시 요청을 쏘고 수업예약 탭에 가드가 있지만 트레이너 네비는 둘 다
없다 — **그 차이가 두 홈 골든의 모양을 가른다.**

`AppNavigationItem`은 아이콘과 라벨의 활성 여부를 **따로** 받는다. 웹
트레이너 네비의 홈 탭이 아이콘은 `/trainer || /trainer/manage`, 라벨은
`/trainer`만 보기 때문이다(L33 vs L41) — `/trainer/manage`에서 아이콘은
켜지고 라벨은 꺼진다. 실측이라 그대로 옮겼다.

**규율 #12에 또 걸렸다.** `_Shortcuts`의 `Row`에 `CrossAxisAlignment.stretch`를
줬다가 `BoxConstraints forces an infinite height`로 30개 테스트가 한꺼번에
터졌다. 웹 `grid-cols-2`의 두 칸은 `h-[140px]`로 높이가 이미 같아서 늘릴
필요도 없었다 — 학생 홈의 `_PointDetail`(`IntrinsicHeight`로 해결)과 같은
뿌리이고, **이 실수를 두 화면 연속으로 했다.**

**라우트 7개를 추가했다.** `/trainer/manage` 아래에서 **`feedback`을
`:memberId`보다 먼저** 선언해야 한다 — go_router는 형제 라우트를 선언
순서로 매칭해서, 반대로 두면 `/trainer/manage/feedback`이
`memberId = 'feedback'`으로 잡힌다.

**파란 배너를 56px 더 그리고 있었다.** 웹 배너는 `absolute top-0
h-[170px]`인데 그 기준이 `<Layout className='relative'>` 안쪽 — **헤더를
포함한** 컨테이너다. 화면 맨 위부터 170px가 파랗고 그중 56px가 헤더 자리다.
Flutter의 `AppBar`는 `Scaffold`가 본문과 **별개 레이어**로 그려서 본문
`Stack`이 그 뒤를 칠할 수 없으므로, 헤더를 직접 `primary500`으로 칠하고
본문에는 `170 - 56 = 114`만 그려야 한다. 그런데 본문에도 170을 그대로
그려서 합이 **226px**가 됐다.

브리프 문서에는 "170은 헤더를 덮는다"고 이미 적어놓고도 구현에서 어겼고,
**43개 테스트가 전부 통과한 채로 넘어갔다** — 높이를 재는 단언이 하나도
없었기 때문이다. 색과 위젯 존재만 확인하는 단언은 "얼마나"를 못 잡는다.
`bannerBodyHeight` 상수를 두고 `AppBar.toolbarHeight + 배너 높이 == 170`을
단언하는 테스트를 추가했다(466번째).

최종: **Dart 466 통과**(420 → 466, +46), Python 30, `verify.sh` 4/4,
analyze `No issues found!`. 뮤테이션 M13·M14·M15 기대대로 실패 확인.
골든 `home-trainer`(GET 3건) 신규 첨부·소비.

## 2026-09-15 — 헬스장 DTO가 둘이었다 (홈 두 화면이 실서버에서 빈 화면)

마이페이지 골든을 뜨다가 `GET /api/v1/members/me`의 실제 응답을 봤다:

```json
"gym": {"id": 1, "name": "건강해짐 홍대점"}
```

**`gymId`가 아니라 `id`다.** 백엔드에 같은 도메인을 담는 record가 둘이고
id 필드명만 다르다:

| record | id 필드 | 쓰는 응답 |
|---|---|---|
| `GymResult` | `gymId` | `GET /api/v1/gyms` (목록) |
| `GymDto` | **`id`** | `members/me` · `home/student` · `home/trainer`의 `gym` |

앱의 `Gym.fromJson`은 `json['gymId'] as int` — **비-null 캐스트**였다. 그래서
`GymDto` 모양이 오면 던졌고, 그 예외를 호출부의 `catch (_)`가 삼켰다.

피해가 트레이너 홈의 헬스장 이름 하나로 끝나지 않았다. `Gym.fromJson`이
**`StudentHome.fromJson` 안에서** 불리므로 학생 홈은 **응답 전체의 파싱이
죽어** 모든 섹션이 빈 상태로 그려졌을 것이다. 수강권·포인트·랭킹·예약·
식단이 전부 사라지는데 화면은 멀쩡히 "데이터 없음"을 그린다.

### 테스트 465개가 이것을 못 잡은 이유

**픽스처를 내가 `gymId`로 썼기 때문이다.** 웹 TS 타입(`Gym {gymId, name}`)과
`openapi/api-docs.json`의 `GymResult`를 보고 gym은 다 그 모양이라고 가정한 채
픽스처를 지었고, 테스트는 그 가정을 충실히 확인해 줬다. **골든은 요청만
대조하지 응답 본문은 대조하지 않는다** — 하네스의 사각지대다.

실서버 응답을 눈으로 본 것이 유일한 발견 경로였다. 이번엔 다른 화면의
골든을 뜨다 우연히 봤다.

### 고치는 방향 — `Gym`을 넓히지 않았다

`json['gymId'] ?? json['id']`로 둘 다 받게 하면 `gymId`가 nullable이 되고,
그 null이 `GymSelectList`의 타일 키와 `POST /api/v1/gyms/{gymId}`까지 번진다.
목록 응답에는 `id` 모양이 오지 않으므로 그 nullable은 순전히 가짜다.

그래서 **둘을 섞지 않았다.** `Gym`은 목록(`GymResult`) 전용으로 두고,
`GymDto`를 받는 쪽(`StudentHome`·`MemberInfo`)은 **실제로 쓰는 값 하나인
이름만** `String gymName`으로 담는다. 화면이 id를 쓰지 않으므로 잃는 것이
없고, `Gym`의 `gymId`는 non-null로 남는다.

`test/entity/gym/gym_test.dart`가 이 결정을 고정한다 — `Gym.fromJson`이
`id` 모양에 **던지는 것**까지 단언한다. 조용히 받아 주면 "섞지 않는다"는
결정이 슬그머니 풀린다.

뮤테이션 둘로 확인했다. M16(이름 키를 `gymName`으로 오타) → 2건 실패,
M17(원래 버그 재주입: `gym['gymId']! as int`) → 2건 실패.

### 픽스처를 실측 모양으로 바꿨다

`home/student`·`home/trainer`·`members/me`의 gym 픽스처 7곳을 `{id, name}`로
고쳤다. `GET /api/v1/gyms` 목록 픽스처는 `gymId` 그대로 둔다 — 그쪽이 진짜
`GymResult`다.

**교훈: 응답 픽스처는 실측에서 온 것만 믿을 수 있다.** 웹 TS 타입은 이
프로젝트에서 이미 여러 번 계약과 어긋났고(규율: 선언이 아니라 소비 측 가드를
보라), 이번엔 **필드 이름 자체**가 달랐다. 새 화면을 옮길 때 골든과 함께
**응답 본문 한 벌을 실측해 픽스처의 뿌리로 삼을 것.**

---

## 2026-09-15 — 회원 마이페이지 허브 (웹 라우트 10/73)

`docs/student-mypage-survey.md`(722줄)로 9개 화면을 먼저 실측하고, 서베이 §7의
순서대로 **허브부터** 옮겼다. 서베이 원안은 허브를 7번째로 미뤘는데 그 근거가
"하단 네비를 먼저 만들어야 하는 셸 작업"이었다 — **그 셸은 학생 홈을 옮기며
이미 만들어 두었다.** 골든도 이미 떠 있어서 허브가 가장 싼 화면이 됐다.

요청은 2건이고 순서가 있다: `members/trainer-mapping`(하단 네비) →
`members/me`(화면). 학생 홈과 같은 모양이라 `addPostFrameCallback`으로 화면
요청을 한 프레임 미뤘다. **`notification/red-dot`은 없다** — 이 화면 헤더에는
알림 종이 없다.

### 위젯 테스트의 글꼴이 실기기와 다르다

바로가기 카드(`w-[320px]`)를 옮기자 테스트가 `RenderFlex overflowed by 23
pixels`로 터졌다. 웹에서는 멀쩡한데다 계산해 보면 들어맞아야 했다.

원인은 레이아웃이 아니라 **글꼴**이었다. `flutter test`의 기본 글꼴은 플랫폼
간 결정성을 위해 **모든 글자를 1em 정사각형으로** 그리고, `pubspec.yaml`에
선언한 글꼴은 자동으로 실리지 않는다. 실측:

| | 테스트 기본 글꼴 | 실제 Pretendard(웹 `getBoundingClientRect`) |
|---|---|---|
| `수업일지`(4자, 16px) | **64.0** | **55.31** |
| `식단`(2자, 16px) | **32.0** | **27.66** |

글자당 16px 대 13.83px, **17% 차이**다. `test/flutter_test_config.dart`를 두어
실제 Pretendard 네 무게를 싣자 `55.3125` / `27.65625`가 나왔다 — 웹 실측과
소수점까지 같다.

**기존 테스트는 하나도 깨지지 않았다.** 지금까지 쓴 단언이 높이·존재 위주였기
때문인데, 뒤집어 말하면 **글자 폭에 관한 한 그동안의 테스트는 실기기를 재고
있지 않았다.**

### Material의 기본 자간 0.25가 모든 글자에 새고 있었다

글꼴을 싣고도 0.78px이 남았다. `TextPainter`로 재면 55.3125인데 위젯으로
그리면 **56.3125**였다 — 글자당 정확히 0.25px.

`Scaffold` 안에서는 Material 3의 `textTheme.bodyMedium`이 `DefaultTextStyle`로
상속되고 그 자간이 0.25다. `TextStyle.inherit`가 기본 true라, 자간을 명시하지
않은 `AppTypography` 스타일들이 그 값을 **전부 물려받고 있었다.** 웹에는
`letter-spacing` 선언이 없으니 `normal`(0)이다.

즉 **지금까지 만든 모든 화면의 모든 글자가 웹보다 글자당 0.25px 넓었다.**
한 줄에서는 안 보이지만 고정 폭 안에 텍스트가 들어가는 레이아웃에서는 그
누적이 곧 오버플로다. `AppTypography`의 16개 스타일에 `letterSpacing: 0`을
못박았다.

`app_typography_test.dart`에 가드 둘을 넣었다. 하나는 **선언**을 보고(16개
스타일 전부 0), 하나는 `Scaffold` 안에 실제로 넣어 **글자 폭 55.31**을 잰다 —
선언만 보는 단언은 "상속을 이기는가"를 못 잡는다.

### 치수는 브라우저에서 직접 쟀다

`getBoundingClientRect`로 받은 값을 그대로 상수로 옮겼다:
프로필 카드 **116**, 메뉴 행 **54**, 바로가기 카드 **320**, 구분선
**2 × 36**, 하단 네비 **81**.

구분선이 특히 그렇다. 웹 클래스는 `w-[1px] border border-gray-200`인데
`box-sizing: border-box` 안에서 좌우 1px 보더가 1px 폭에 들어가려다 충돌해
**2px로 렌더된다**(서베이 BUG-22). 클래스만 읽고 1px로 옮겼으면 카드 안
세 칸의 위치가 전부 어긋났다.

라벨 폭도 추측이 틀렸다. 한글은 보통 1em이라 4글자 64px로 계산했는데 실제로는
**55.31px**(글자당 0.864em)이었다. Pretendard의 한글이 그만큼 좁다. 64로
계산했으면 "웹도 넘친다"는 잘못된 결론에 도달했을 것이다.

### 그 밖에

- `MemberInfo`를 여섯 필드로 넓혔다(`name`·`userId`·`email`·`socialType`·
  `profile.fileUrl`·`gym.name`). 웹 타입의 `age`·`height`·`weight`·`delYn`은
  **응답에 아예 없어서**(서베이 BUG-19) 담지 않았다.
- `AppLayoutHeader.backgroundColor`를 열었다. 허브는 **헤더만 흰색이고 본문은
  gray-100**이라 `AppLayout.backgroundColor`로는 안 된다.
- 규율 #12에 또 걸릴 뻔했다. Column 끝에 `Expanded`로 남은 자리를 칠하려다
  멈췄다 — 본문이 `SingleChildScrollView` 안이라 높이 상한이 없다. 필요도
  없었다(Column이 안 칠하면 Scaffold 배경이 그대로 드러난다).
- 하위 라우트 8개를 자리표시자로 등록했다. `edit/name` 같은 **2세그먼트 자식
  경로**가 go_router에서 매칭되는지는 가정이었는데, 화면 테스트는 라우터를
  끼우지 않으므로(규율 #3) `app_test`에 등록 확인 8건을 넣어 실측했다.

뮤테이션 넷을 확인했다. M19(postFrame 제거 → 요청 순서 뒤집기), M20(계정 라벨
분기 제거), M21(구분선 2 → 1), M22(`heading1`의 자간 선언 제거). **M22는 처음에
안 잡혔다** — 자간 가드를 그때 추가했다.

최종: **Dart 515 통과**(480 → 515, +35), `verify.sh` 4/4,
analyze `No issues found!`. 골든 `mypage-student`(GET 2건)·
`mypage-student-info`(GET 1건) 신규 첨부, 전자를 소비.

## 2026-09-15 — 회원 마이페이지 내 정보 (웹 라우트 11/73)

허브 다음 차례. 골든 `mypage-student-info`(GET 1건)는 이미 떠 있었다.
**하단 네비가 없어 허브(2건)와 다르고**, 순서를 맞출 상대가 없어
`addPostFrameCallback`도 필요 없었다.

### `AuthState.signOut()`의 프로덕션 호출부 0개가 풀렸다

Phase 0부터 남아 있던 부채다. 로그아웃 버튼이 이 화면에 있다.

웹은 성공 후 넷을 한다 — `deleteUserInfo()` · `localStorage.clear()` ·
서비스워커 `unregister()` · `router.push('/')`. 앱은 둘로 줄였다:

- `localStorage.clear()`는 옮기지 않았다. 이 앱이 로컬에 두는 것은 토큰과
  프로필뿐이고 `signOut()`이 그 둘을 지운다 — **지울 나머지가 없다.**
- 서비스워커는 PWA 전용이라 대응물이 없다.
- `onNavigate('/')`는 **반드시 있어야 한다.** `signOut()`의 알림만으로는
  화면이 넘어가지 않는다 — 라우터의 리다이렉트는 이동이 일어날 때
  계산된다(`/select-gym`에서 이미 겪은 것). 뮤테이션 M24로 확인했다.

**실패하면 로그아웃하지 않는다.** 웹도 `onError`에서 토스트만 띄우고 토큰을
그대로 둔다. M23(실패해도 지우기)으로 이 가드가 살아 있음을 확인했다.

### 계정 종류에 따라 카드가 통째로 갈린다

일반 계정은 이름·이메일·비밀번호 변경 **세 줄 다 링크**이고, 소셜 계정은
이름·이메일·계정 연동 설정 **세 줄 다 링크가 아니다**(화살표도 없다).
판정은 `socialType !== 'NONE'`이라 **모르는 값도 소셜로 친다**(서베이 BUG-5) —
그대로 옮겼고 M25로 고정했다. `APPLE`에는 웹에 분기가 없어 배지 자리가 빈다.

### 상수를 기댓값으로 쓴 단언이 공허했다

아바타 크기를 고정하려고 이렇게 썼다:

```dart
final avatar = find.byWidgetPredicate(
  (w) => w is SvgPicture && w.width == StudentMyPageInfoPage.avatarFallbackSize,
);
expect(tester.getSize(avatar), const Size(
  StudentMyPageInfoPage.avatarFallbackSize,
  StudentMyPageInfoPage.avatarFallbackSize,
));
```

**상수를 82에서 80으로 바꿔도 통과한다** — 기댓값이 함께 움직이기 때문이다.
뮤테이션 M26이 그것을 드러냈다. 리터럴 `82`로 바꾸니 잡혔다.

이 화면에서 82는 특히 중요하다. **허브는 80인데 여기만 82다** — 웹이 이
화면에서만 `<IconAvatar width={82} height={82} />`를 쓴다. 맞추면 웹과
달라진다. 규율 #18로 올렸다.

### 치수를 브라우저에서 다시 쟀다

허브에서 두 번(라벨 폭·구분선 폭) 추측이 틀렸던 터라 이 화면도 실측했다.
결과는 구현과 전부 일치했고, 그중 둘은 눈으로 봤으면 놓쳤을 값이다:

| 요소 | 웹 실측 | 계산으로 짐작했다면 |
|---|---|---|
| 카메라 버튼 | **38 × 34** | 36 × 32 (테두리 1px × 2를 빼먹는다) |
| 카드 행 | **63.41 / 63.41 / 62.41** | 62.4 셋 (`border-b` 1px을 빼먹는다) |
| 하단 세로선 | 1 × 10 | — (허브의 바로가기 구분선은 2px였다) |

Flutter `Container`도 `decoration`의 보더 두께를 패딩에 더하므로 38 × 34가
그대로 나온다. **행의 마지막 줄만 1px 작은 것**이 `border-b`가 없다는 증거라,
`rowHeight('이름') - rowHeight('비밀번호 변경') == 1`을 단언으로 박았다.

**줄 높이는 웹과 0.4px 다르다.** Flutter가 줄 높이를 정수로 반올림한다 —
`HEADING_2`는 `22 × 1.3 = 28.6` → **29.0**, `TITLE_1_SEMIBOLD`는
`16 × 1.4 = 22.4` → **22.0**. 브라우저는 소수를 그대로 쓴다. 그래서 허용
오차를 0.5로 뒀다. 패딩이 한 단만 틀려도 4px 이상 어긋나므로 이 오차에
가려지지 않는다(M27: 카메라 패딩 6 → 8이 잡혔다).

### 그 밖에

- **`camera.svg`에 `fill="current"`가 있었다**(규율 #13). `currentColor`로
  정규화하고 `SvgTheme(currentColor: gray500)`로 주입했다.
  `assets_test.dart`의 픽셀 프로브에 넣어 **실제로 그려지는 것까지** 확인했다.
- `MemberApi.logout()`은 **응답 본문이 없다.** 컨트롤러가 `ApiResult`가 아니라
  `void`를 반환해서 이 프로젝트의 다른 요청과 껍데기가 다르다.
- 로그아웃에 재진입 가드를 넣었다. 웹에는 없다(의도적 이탈, 기록함).
- 테스트에서 응답을 바꿔 다시 펌프할 때는 **키를 줘야 한다.** 키가 없으면
  Flutter가 기존 Element를 재사용해 `initState`가 다시 돌지 않고, 바꾼
  응답이 반영되지 않는다 — 소셜 타입 셋을 한 테스트에서 돌리다 걸렸다.

최종: **Dart 549 통과**(515 → 549, +34), `verify.sh` 4/4,
analyze `No issues found!`. 골든 `mypage-student-info` 소비.
뮤테이션 M23·M24·M25·M27 확인, **M26은 처음에 안 잡혀** 단언을 고쳤다.

## 2026-09-15 — 회원 탈퇴 (웹 라우트 12/73)

**골든이 없는 첫 화면이다.** 진입 시 아무 요청도 하지 않고, 유일한 요청인
`POST /api/v1/members/delete`는 **공유 체험 계정을 실제로 지우므로 캡처할 수
없다**(`/select-gym`의 등록 POST와 같은 부류). 요청의 모양은 계약 단언이
고정한다 — 메서드·경로·본문 없음·`authorization` 있음.

브라우저로 치수를 재러 들어갔을 때도 **`탈퇴하기`는 누르지 않았다.**
다이얼로그를 열어 재고 닫았다.

### 확인 다이얼로그의 두 버튼이 생각보다 많이 달랐다

실측이 없었으면 전부 틀렸을 값들이다:

| | 취소 | 탈퇴하기 |
|---|---|---|
| 글꼴 | **16px / 400** | **14px / 500** |
| 모서리 | **8**(`rounded-md`) | **12**(`rounded-lg`) |
| 배경 | gray-100 | **`#EF4444`** |
| 폭 | 129.67 | 140.33 |
| 높이 | 50 | 50 |

`탈퇴하기`의 빨강은 **`--point-color`(`#FF4668`)가 아니다.** 같은 화면의
`계정 삭제하기` 버튼은 point를 쓰는데 다이얼로그 버튼만 shadcn 기본
`--destructive`를 쓴다. "빨간 버튼이니 point겠지"로 넘어갔으면 틀렸다.

**글꼴이 갈린 이유**도 실측으로만 알 수 있었다. `탈퇴하기`는 `<Button>`이라
`button.tsx` base의 `text-sm font-medium`(14/500)이 그대로 걸리고, `취소`는
`DialogClose`라 Tailwind preflight의 `font-size: 100%`로 부모의 16px를
물려받는다. **웹 버튼의 기본 라벨 스타일이 그대로 드러나는 첫 화면**이다 —
지금까지 옮긴 버튼들은 웹이 `Typography.TITLE_1*`로 덮고 있었다.

### 높이 50은 `탈퇴하기`가 늘어난 결과다

`탈퇴하기`의 내용상 높이는 **46**이다(패딩 26 + 줄 높이 20). 웹에서 50인
것은 버튼 행이 flex 기본 `align-items: stretch`라 `취소`(50)에 맞춰
늘어나기 때문이다.

Flutter에서는 `IntrinsicHeight`가 그 일을 한다 — 높이 상한을 "가장 큰
자식만큼"으로 묶으면 두 버튼의 `Container(alignment:)`가 그 느슨한 상한을
꽉 채운다. 학생 홈 `_PointDetail`과 같은 해법이다.

### 뮤테이션이 죽은 코드 둘을 찾았다

**M28 — 동의 가드가 도달 불가능했다.** `_confirmAndDelete`에
`if (!_agreed) return;`을 두었는데, 지워도 아무 테스트가 깨지지 않았다.
버튼이 이미 `onTap: enabled ? onPressed : null`이라 애초에 그 경로로
들어올 수 없었다. 지우고 "진짜 가드는 버튼에 있다"를 주석으로 남겼다.

**M30 — `CrossAxisAlignment.stretch`도 죽은 코드였다.** 위의 높이 맞춤이
`IntrinsicHeight` + `Container(alignment:)` 조합만으로 이미 되고 있었다.
`IntrinsicHeight`까지 지우니(M31) 그제야 46이 나왔다 — 그것이 실제로
일하는 쪽이다.

**파괴적 동작에 방어를 겹겹이 두고 싶은 유혹이 있지만**, 테스트가 닿지
않는 가드는 있다는 착각만 준다. 둘 다 지우고 왜 지웠는지 적었다.

### 단언이 엉뚱한 위젯을 재고 있었다

`find.ancestor(of: find.text('탈퇴하기'), matching: Container)`의 `.first`가
**내가 의도한 버튼이 아니었다.** 그래서 M30을 넣어 버튼 높이가 50 → 46으로
갈려도 테스트가 통과했다. 배경색으로 직접 지목하게 바꾸니 잡혔다.

같은 함정을 이 세션에서 두 번째로 밟았다(내 정보 화면의 구글 배지도
흰 원이라 카메라 버튼과 함께 잡혔다). 규율 #19로 올렸다.

### 그 밖에

- `no_circle_check.svg`에 `fill="current"`가 있었다(규율 #13). 정규화하고
  픽셀 프로브로 실제로 그려지는 것까지 확인했다.
- **체크 표시는 꺼져 있을 때도 그려진다.** 웹이 `fill='white'`를 늘 주므로
  흰 배경에서 안 보일 뿐이다 — 조건부 렌더가 아니라 그대로 옮겼다.
  배경이 흰색이 아닌 곳에 재사용하면 드러난다(기록함).
- 다이얼로그 본문 간격이 **20과 34**다. `DialogContent` base의 `gap-4`(10)가
  `flex flex-col`로 덮어도 살아 있어서 본문의 `mt-4`(10)·`mt-8`(24)와
  **더해진다.** 둘 중 하나만 옮기면 절반이 된다.
- 유의사항 제목 아래는 **8**이다. `ul`의 `mt-3`(8)과 첫 `li`의 `mt-2`(6)가
  **마진 병합**되어 큰 쪽만 남는다 — 더해서 14를 주면 웹보다 벌어진다.
- **탈퇴가 `localStorage.clear()`를 안 하는 웹 버그(BUG-13)는 이관하면서
  저절로 해소됐다.** 앱은 토큰과 프로필이 로컬 상태의 전부라 `signOut()`
  하나로 둘 다 지워진다.

최종: **Dart 574 통과**(549 → 574, +25), `verify.sh` 4/4,
analyze `No issues found!`. 골든 없음(설계).
뮤테이션 M29·M31·M32·M33 확인, **M28·M30은 죽은 코드를 드러냈다.**

## 2026-09-15 — 비밀번호 변경 (웹 라우트 13/73)

2스텝 화면이고 **골든이 없다.** 요청 둘(`POST` 확인 / `PATCH` 변경)이 같은
경로를 메서드로 가르는데, **둘 다 본문에 비밀번호가 들어가** 캡처하면 HAR에
평문이 남는다. 계약은 테스트가 고정한다 — 특히 본문 키
`changePassword1`·`changePassword2`는 뮤테이션(M35)으로 확인했다.

### 죽은 CSS 클래스를 실측으로 잡았다

힌트 문단에 `mt-7`(20)이 붙어 있는데 **실제 간격은 8**이었다. Tailwind의
`space-y-3`이 `.space-y-3 > :not([hidden]) ~ :not([hidden])` 선택자라 단일
클래스 `mt-7`보다 특정도가 높아서다.

CSS 특정도를 따져 "아마 8일 것"이라고 추론은 했지만, **그 추론을 믿고 넘어가지
않고 브라우저에서 쟀다.** `mt: "8px"`로 확인됐다. 디자인 의도는 20이었을
가능성이 높지만 웹의 현재 렌더는 8이고, 이 프로젝트는 렌더를 옮긴다.

### 웹 버튼 기본 라벨 스타일이 두 번째 사용처를 만났다

제출 버튼이 **400 × 56에 14px / 500**이다. `AppButton.defaultHeight`(44)도,
기본 라벨(`title1SemiBold`, 16/600)도 아니다 — 웹이 이 버튼을 덮지 않아
`button.tsx` base(`text-sm font-medium`)가 그대로 드러난다.

`leave`의 다이얼로그 `탈퇴하기`가 첫 번째였고 여기가 두 번째라,
프로젝트 규칙대로 **`AppButton.baseLabel`로 승격**했다. 두 화면이 그것을
참조한다.

**기본값은 바꾸지 않았다.** 이미 옮긴 화면들은 웹이 `Typography.TITLE_1*`로
덮고 있어 16px가 맞다 — 기본값을 base로 바꾸면 그 화면들이 전부 틀어진다.
그 이유를 상수 주석에 적었다.

### 웹의 비제어 입력 버그를 그대로 재현했다

확인 실패 시 웹은 `setPassword('')`를 부르는데, `<Input>`이 **비제어**라
화면의 글자는 그대로 남는다. 결과적으로 **글자가 보이는데 버튼이 비활성**인
상태가 된다.

Flutter에서 이것을 재현하는 방법은 **컨트롤러를 두지 않는 것**이었다.
`TextField`가 자기 내부 상태로 글자를 들고 있고, 화면 상태(`_password`)만
비우면 웹과 같은 어긋남이 그대로 생긴다. 테스트가 그 둘을 함께 단언한다 —
`find.text('wrong-pass')`는 찾히고 버튼은 꺼져 있다.

`obscureText: true`인데도 `find.text`가 원문을 찾는다는 점이 유용했다
(`EditableText`의 컨트롤러 값을 본다).

### 그 밖에

- **입력을 `AppTextInput`으로 만들지 않았다.** 그 위젯은 라벨을 요구하고
  높이가 50인데, 웹은 여기서 라벨 없는 맨 `<input>`을 쓰고 상자 높이가
  **52**(패딩 26 + 줄 높이 24 + 테두리 2)다. 제목은 입력의 라벨이 아니라
  섹션의 `<h3>`다. `/edit/name`·`/edit/email`이 같은 모양을 쓰므로 그때
  공용으로 올린다.
- `TextField`에 `border: InputBorder.none` + `isDense` + `contentPadding:
  zero`를 줘야 52가 나온다. 기본 `InputDecoration`은 자기 패딩을 12~16
  더해서 상자가 웹보다 두꺼워진다.
- 힌트 문단은 `Wrap`으로 옮겼다. 웹이 인라인 텍스트라 좁아지면 줄바꿈되는데
  `Row`는 넘친다.
- **길이·형식 검증이 화면에 없다.** 플레이스홀더가 "8자리 이상"이라 말하지만
  두 값이 같기만 하면 버튼이 활성된다 — 그대로 옮기고 테스트로 고정했다.

최종: **Dart 599 통과**(574 → 599, +25), `verify.sh` 4/4,
analyze `No issues found!`. 골든 없음(설계).
뮤테이션 M34·M35·M36·M38 전부 기대대로 실패 확인.

## 2026-09-15 — 이름 변경 (웹 라우트 14/73)

가벼운 화면인데 배운 것이 셋 있다.

### 요청 목록이 같아도 골든을 따로 떴다

`mypage-student-edit-name`은 `members/me` 한 건이라 `mypage-student-info`와
**내용이 완전히 같다.** 그래도 따로 캡처했다(규율 #2).

공유하면 한쪽이 요청을 늘렸을 때 **어느 화면이 달라졌는지 알 수 없다** —
두 테스트가 같이 깨지고 고치는 사람이 둘 중 하나를 임의로 고른다.
`har/README.md`에 그 이유를 적었다.

### 입력 상자를 공용으로 올렸다

`/edit/password`가 첫 사용처, 여기가 두 번째라 규칙대로 `AppPlainInput`으로
승격했다. `AppTextInput`(라벨 필수, 높이 50)과 다른 물건이다 — 웹이 두 모양을
실제로 나눠 쓰고, 마이페이지 편집 폼은 **섹션 제목이 따로 있어서** 입력에
라벨을 붙이지 않는다. 높이도 52로 다르다.

승격이 값을 했다: 패딩을 13 → 12로 바꾼 뮤테이션(M42)이 **두 화면의 테스트에서
동시에** 잡혔다.

### 동치 뮤테이션을 만났다

`_loadMe`에서 상태에도 이름을 넣어 봤는데(M40) 아무 테스트도 깨지지 않았다.
처음엔 테스트 구멍인 줄 알았지만, `_canSubmit`의 `_name != _me?.name`이
`_name == ''` 경우를 **이미 포섭**해서 관측 차이가 없었다 — 진짜 동치다.

이 경우 할 일은 테스트를 늘리는 것이 아니라 **주석을 정정하는 것**이었다.
"입력창에 보이는 글자와 상태가 다르다"고 단정해 뒀는데, 그 차이가 화면
동작으로 드러나지 않는다는 사실을 함께 적었다. 죽은 코드(M28·M30)와는
다르게 처리해야 하는 부류다.

### 서베이 두 항목을 정정했다

- **BUG-6(토스트 폴백 누락)은 무해하다.** 호출부에 `?? '문제가 발생했습니다.'`가
  없는 건 맞지만 웹 `errorToast`가 자체 폴백을 갖고 있다(`use-toast.tsx:213`).
- **BUG-16(`defaultValue` 갱신 안 됨)은 첫 로딩에서는 안 일어난다.** 실측에서
  입력창에 `차은우`가 정상으로 채워졌다. React가 `defaultValue` 변경을 `value`
  **속성**에 반영하고, 사용자가 손대지 않은 입력은 속성을 따라간다.
  **한 번 입력한 뒤**에야 막히는데 이 화면엔 그 뒤 refetch가 없다.

정적 분석만으로 쓴 서베이가 두 번 어긋났다 — 둘 다 **브라우저에서 눈으로 본
것**이 바로잡았다.

### 그 밖에

- 웹은 이동 전에 `refetchQueries(['myinfo'])`를 부른다. 앱에는 공유 캐시가
  없고 돌아간 화면이 자기 `initState`에서 같은 GET을 하므로 옮기지 않았다 —
  **나가는 요청은 같고 순서만 다르다.** 테스트가 "이동 전에 재조회하지
  않는다"로 그 결정을 고정한다.
- 제출 버튼은 `/edit/password`와 같은 56 높이 + `AppButton.baseLabel`이다.

최종: **Dart 617 통과**(599 → 617, +18), `verify.sh` 4/4,
analyze `No issues found!`. 골든 `mypage-student-edit-name`(GET 1건) 신규.
뮤테이션 M39·M41·M42 확인, **M40은 동치로 판정**했다.

## 2026-09-15 — 알림 설정 (웹 라우트 15/73)

마이페이지 계열 여섯 번째. 요청은 진입 1건이고 **토글마다 2건**이다.

### 웹 버그를 "고치지 않는" 것을 테스트로 지켰다

커뮤니티 스위치의 게이트가 `communityAlarmStatus`가 아니라
**`scheduleNoticeStatus`**다(서베이 BUG-1). 같은 행 안에서 게이트와 켜짐
판정이 **서로 다른 필드**를 본다.

그대로 옮기는 것은 쉬운데 **지키는 게 어렵다** — 나중에 누가 보면 오타로
보여서 고치고 싶어진다. 그래서 M43(게이트를 올바른 필드로 "고치기")을
넣어 테스트가 잡는지 확인했다. 두 테스트가 깨진다.

이 계열에서 **의도적 버그를 뮤테이션으로 지킨 첫 사례**다. 지금까지는
버그를 기록만 했지 "고치면 깨지는" 가드를 두진 않았다.

### 낙관적 갱신이 없다는 것도 계약이다

스위치를 누르면 `PATCH` → **`members/me` 재조회** → 그 결과로 스위치가
움직인다. 웹이 `await refetchQueries(['myinfo'])`로 하는 일이다.

`/edit/name`에서는 같은 재조회를 **옮기지 않았다**(이동해 버리므로 목적지
화면이 스스로 부른다). 여기서는 화면 자신이 그 값을 쓰므로 **반드시 옮겨야
한다.** 같은 웹 코드라도 화면에 따라 판단이 갈린다는 게 요점이다.

"응답 전에는 스위치가 움직이지 않는다"를 단언으로 박았다 — 낙관적 갱신을
넣는 것은 UX 개선처럼 보이지만 웹과 달라지는 변경이다.

### 스위치가 행 높이를 정한다

첫 행이 **64**인데 글자는 24다. 스위치가 28이고 `items-center`라
`18 + 28 + 18 = 64`가 된다. 글자로 계산했으면 60으로 틀렸다.

스위치 자체도 클래스만 읽으면 틀린다. **트랙 높이 28은 어디에도 안 적혀
있다** — `border-2`(투명) + 손잡이 24 + 2로 만들어지는 값이고, 그래서 이동
거리도 `48 - 4 - 24 = 20`으로 떨어진다. 트랙에 세로 패딩을 주는 방식으로
옮기면 그 관계가 끊어진다. `AppSwitch`로 공용화하면서 이 유도 과정을
주석에 남겼다.

### 그 밖에

- 제목 "알림 설정"이 **헤더가 아니라 본문 첫 블록**이다(흰 배경 `<h1>`,
  높이 70). 헤더는 뒤로가기만 있는 흰 바이고 루트는 gray-100이라,
  허브와 같이 `AppLayoutHeader.backgroundColor`로 헤더만 희게 했다.
- 행 사이 구분선이 **없다.** 첫 행과 둘째 행 사이의 `mt-3`(8) 회색 틈이
  그 역할을 하고, 둘째·셋째 행은 아예 붙어 있다.
- `MemberInfo`에 알림 4종을 추가했다. 내 정보 화면을 옮길 때 "쓰는 화면이
  생기면 넣는다"고 적어 뒀고 약속대로 지금 넣었다. **enum으로 좁히지
  않았다** — 웹이 같은 필드를 "값이 있는가"(게이트)와 "ENABLED인가"(켜짐)
  두 가지로 보기 때문이다.
- **`SCHEDULENOTICE`를 끌 방법이 앱·웹 어디에도 없다**(BUG-2). 타입과
  백엔드에는 있는데 화면에 자리가 없다.

### 못 본 것

**켜진 스위치를 보지 못했다.** 실측 계정의 알림 4종이 전부 `DISABLE`이고,
스위치를 누르면 공유 계정 설정이 실제로 바뀌어서 누르지 않았다. 켜짐
색(`#1990FF`)은 `switch.tsx`의 `bg-primary`와 `tailwind.config.js`의
`primary.DEFAULT = var(--primary-500)`를 따라가 얻은 값이다 — 이번 화면에서
유일하게 **눈으로 확인하지 못한 값**이라 이월에 적었다.

최종: **Dart 640 통과**(617 → 640, +23), `verify.sh` 4/4,
analyze `No issues found!`. 골든 `mypage-student-alarm`(GET 1건) 신규.
뮤테이션 M43·M44·M46 확인, M45(재조회를 await 하지 않기)는 관측 차이가
없어 동치로 판정했다.

## 2026-09-15 — 트레이너 정보 (웹 라우트 16/73)

마이페이지 계열 일곱 번째. 요청 1건, 뮤테이션 0개.

### 골든에 401 리프레시가 섞여 들어올 뻔했다

캡처 중 네트워크에 이렇게 찍혔다:

```
GET  .../trainer-mapping/info  => 401
POST /api/v1/auth/refresh-token => 200
GET  .../trainer-mapping/info  => 200
```

액세스 토큰이 만료돼 **웹 인터셉터가 자동으로 갱신**한 것이지 화면이 보내는
요청이 아니다. 그대로 담았으면 앱 테스트가 "리프레시 요청이 없다"는 이유로
영영 실패했을 것이다 — **401 리프레시는 이 프로젝트의 Phase B 항목**이라
앱에 아직 그 경로가 없다.

골든에는 성공한 1건만 담고, `har/README.md`에 "변환 전에 entries를 훑어
401·`refresh-token`이 섞이지 않았는지 확인하라"를 추가했다. 캡처가 길어질수록
걸리기 쉬운 함정이다.

### 웹 버그를 지키는 가드를 또 두었다

`{!data && <NoTrainer />}`에 `isLoading` 분기가 없어 **조회 중에 "등록된
트레이너가 없습니다."가 먼저 깜빡인다**(BUG-10). 로딩 분기를 "추가"하는
뮤테이션(M47)이 테스트에 잡히는 것을 확인했다.

알림 화면의 BUG-1에 이어 **두 번째**다. 이 계열의 버그들은 하나같이
"고치고 싶어지는" 모양이라, 기록만으로는 부족하고 가드가 필요하다.

### `py-28`은 커스텀 스케일이 아니다

빈 상태의 위아래 여백이 **112**다. 이 프로젝트의 커스텀 스페이싱 스케일은
**1~12만 덮고** 13 이상은 Tailwind 기본값(rem)이 그대로 남는다.
28 → `7rem` → 112px.

커스텀 스케일로 착각하면 "28은 없는 값"이 되어 헤매게 된다. 서베이 §6-0이
이미 경고해 둔 항목인데, 실제로 만난 것은 이번이 처음이다.

### 그 밖에

- **헤더에 배경이 없다.** 루트도 헤더도 gray-100이다 — 알림 화면(헤더만
  흰색)·허브와 다르다. 같은 계열 안에서 세 가지 조합이 나온다.
- 이름과 정보 값이 **순검정(`text-black`)**이다. `gray800`(`#2E3134`)이
  아니다 — 이 화면만 그렇다.
- 프로필 사진이 **`object-contain`**이다. 허브·내 정보는 `object-cover`다.
- 이미지 URL이 `?w=300&h=300&q=90`으로 **정상**이다. `info` 화면만 `&=q=90`
  오타다(BUG-4) — 같은 프로젝트 안에서 두 줄이 다르다.
- `TrainerInfo`는 여섯 필드 중 넷만 담는다. `mappingId`와 `trainer.id`는
  화면이 읽지 않는다.

### 못 본 것

**빈 상태를 브라우저에서 보지 못했다.** 실측 계정에 트레이너가 연결돼 있어서
데이터 있는 화면만 쟀다. `py-28`·`mb-5`·아이콘 35×36은 클래스에서 읽은
값이고, 매핑 없는 계정을 구하면 대조해야 한다. 프로필 사진이 있는 트레이너도
못 봤다(실측 계정의 트레이너 `profile`이 null).

최종: **Dart 658 통과**(640 → 658, +18), `verify.sh` 4/4,
analyze `No issues found!`. 골든 `mypage-student-trainer-info`(GET 1건) 신규.
뮤테이션 M47·M48 기대대로 실패 확인.

## 2026-09-15 — 이메일 변경 (웹 라우트 17/73)

마이페이지 계열 여덟 번째. **실제 패리티 구멍을 하나 메웠다.**

### 앱만 토큰을 붙이고 있었다

웹은 인증번호 발송(`POST /api/v1/auth/validation/send-email`)을 **토큰 없는
`api` 인스턴스**로 보낸다. 앱의 `AuthInterceptor._publicPaths`에는
`/auth/login`·`/auth/join`·`/auth/refresh-token`·`/auth/find/`만 있었고
`/auth/validation/`이 없어서, **앱만 `Authorization`을 붙이고 있었다.**

**마이페이지 아홉 화면 중 토큰 없이 나가는 요청은 이것 하나**다. 이 화면을
옮기지 않았으면 영영 몰랐을 것이다. 서베이가 "토큰 없는 인스턴스가 섞인
유일한 화면"이라고 표시해 둔 덕에 API를 쓰기 전에 인터셉터부터 확인했다.

뮤테이션 M49(그 줄 제거)가 테스트에 잡히는 것을 확인했다.

### 클래스만 읽었으면 4px 틀렸다

2단계 인증번호 상자가 **56**이다. 상자 자신의 클래스(`py-[13px]`)로는 52인데,
옆의 `재전송` 버튼이 `py-[18px]`로 56이고 행이 flex(`align-items: stretch`)라
상자가 끌려 올라간다.

처음 구현에서 `재전송`에 **가로 패딩만 주고 세로를 빠뜨려** 행이 52에
머물렀다 — 테스트가 바로 잡았다. `leave` 다이얼로그의 두 버튼과 정확히
같은 현상인데, 그때 배운 것이 여기서 값을 했다.

### 웹 버그 둘을 뮤테이션으로 지켰다

- **BUG-15**: 2단계에서 인증번호 칸이 이메일 칸보다 **위**다. 웹 DOM 순서가
  그렇다. M52(순서 바로잡기)가 네 테스트를 깨뜨린다.
- **BUG-14**: 재전송에 성공·실패 피드백이 **없다**. 웹이 콜백을 하나도
  넘기지 않아 눌러도 화면이 아무 반응을 하지 않는다. M51(에러 토스트 추가)이
  잡힌다.

알림(BUG-1)·트레이너 정보(BUG-10)에 이어 **세·네 번째**다. 이제 이 계열의
의도적 버그는 전부 "고치면 깨지는" 가드를 갖는다.

### 2단계를 보려고 실제 메일을 보냈다 — 예약 도메인으로

2단계는 `인증 요청`을 눌러야 나오고 그 버튼이 실제 메일을 보낸다.
`find/password` 재캡처와 같은 규칙으로 **RFC 2606 예약 도메인**
`parity-harness@example.com`을 썼다 — 배달되지 않으므로 아무에게도 가지 않는다.

**`인증 완료`는 누르지 않았다.** 그것이 계정의 이메일을 실제로 바꾼다.
그래서 인증번호가 찬 상태의 화면은 못 봤고, 이월에 적었다.

### 그 밖에

- `AppPlainInput`에 `readOnly`와 `alignment: topLeft`를 더했다. 후자는
  **부모가 높이를 정해 줄 때만** 의미가 있다 — 높이 상한이 없는 보통의
  경우에는 `Align`이 자식 크기를 따라가므로 다른 두 화면(52)이 그대로다.
  세 화면이 같이 검증한다.
- `재전송` 버튼은 `AppButton`을 쓰지 않았다. 그 위젯은 폭을 꽉 채우는
  제출 버튼용인데 이것은 **글자 폭만큼**이다(실측 68.31).
  색도 이 화면에만 나오는 `gray-700`이다.
- 이메일 칸은 2단계에서 `readOnly`다 — `disabled`가 아니라 흐려지지 않는다.

최종: **Dart 680 통과**(658 → 680, +22), `verify.sh` 4/4,
analyze `No issues found!`. 골든 `mypage-student-edit-email`(GET 1건) 신규.
뮤테이션 M49·M50·M51·M52 전부 기대대로 실패 확인.

## 2026-09-15 — 지난 예약 (웹 라우트 18/73) · 마이페이지 계열 완료

계열에서 가장 무거운 화면이자 마지막이다. 새 위젯 둘(월 선택 시트, 상세
시트), 새 엔티티 하나(`schedule`), 날짜 포맷터 셋이 함께 들어왔다.

### 쿼리스트링까지 골든이 고정한다

`GET .../my-reservation/old?searchDate=2026-09` — 이 계열에서 **쿼리가 있는
첫 골든**이다. `har_to_golden.py`가 `query` 필드로 담고 `expectParity`가
대조한다.

### 웹 버그 넷을 뮤테이션으로 지켰다

- **BUG-8**: `?month=`가 없으면 `searchDate=Invalid Date`를 **그대로 보낸다.**
  오늘로 대체하는 M53이 잡힌다. 그때 월 선택기도 함께 사라진다.
- **BUG-9**: 로딩 중에는 빈 상태조차 안 뜬다(완전 공백). M56이 잡는다.
- **빈 배열 ≠ 빈 상태**: 서버가 지금은 `null`을 주지만 `[]`로 바뀌면
  **빈 상태가 영영 안 뜬다.** 모델이 null을 흡수하지 않아야 하는 이유이고
  M54가 그것을 지킨다.
- **시각 포맷이 화면마다 다르다**: 여기는 한 자리 시(`오전 4:00`), 학생 홈은
  두 자리(`오후 02:30`). M55가 잡는다.

마이페이지 계열에서 의도적 버그를 지키는 가드가 이제 **여덟 개**다
(알림 1, 트레이너 정보 1, 이메일 2, 지난 예약 4).

### 시각 변환을 파싱하지 않았다

웹 `convertTo12HourFormat`은 `time.split(':')`로 문자열만 자른다. `intl`로
파싱해 `DateFormat('a h:mm')`을 쓰면 **결과는 같지만 실패할 자리가 생긴다** —
이 프로젝트는 시각 파싱으로 이미 크게 데였다(트레이너 홈 BUG-1의 dayjs
Invalid Date). 웹과 같이 자르기만 하도록 옮겼다.

### 시트 높이 상한을 풀어야 했다

Flutter `showModalBottomSheet`은 기본으로 시트를 **화면의 9/16**으로 묶는다.
웹 시트는 `fixed bottom-0`이라 그런 상한이 없고, 월 선택 시트 내용이 457이라
테스트(800 × 600)에서 118px 넘쳤다. `isScrollControlled: true`로 풀었다.

**좁은 화면에서만 드러나는 종류**라 규율 #14(폰 너비 테스트)가 없었으면
실기기에서 처음 봤을 것이다 — 여기서는 기본 뷰포트가 이미 좁아 먼저 걸렸다.

### 같은 `gap-4`가 한 시트에서는 무력하고 다른 시트에서는 덮인다

시트 기본 클래스에 `gap-4`(10)가 있는데:
- **상세 시트**: `flex`가 아니라 **아무 효과가 없다.** 간격은 자식의
  `mb-8`(24)·`mb-11`(36)만 만든다.
- **월 선택 시트**: className이 `flex flex-col gap-7`이라 **20으로 덮인다.**

둘 다 실측으로 확인했다. 클래스만 읽고 "gap 10"으로 옮겼으면 두 시트 다
틀렸을 것이다.

### 데스크톱 스크롤바를 값으로 착각할 뻔했다

카드 폭이 **385**로 잡혔다. 400이어야 하는데 15px이 빈다 — 목록이 길어
데스크톱 스크롤바가 생긴 것이다. 앱에는 그 스크롤바가 없으므로 400이 맞다.
실측값을 그대로 박는 습관의 반대 방향 함정이라 `har/README.md`에 적었다.

### 데이터가 있는 달을 찾는 데 시간이 걸렸다

실측 계정은 **2026-04에만 10건**이고 나머지는 전부 `null`이었다. 달을
하나씩 열어 보는 대신 콘솔에서 토큰을 꺼내 여섯 달을 한 번에 훑었다 —
그 스니펫을 `har/README.md`에 남겼다.

### 마이페이지 계열 아홉 화면 정리

| 화면 | 골든 | 특징 |
|---|---|---|
| 허브 | 2건 | 하단 네비가 1번을 쏜다 |
| info | 1건 | **`AuthState.signOut()` 부채 해소** |
| leave | 없음(설계) | 확인 다이얼로그 첫 레퍼런스 |
| edit/password | 없음(설계) | 본문에 비밀번호 — 캡처 금지 |
| edit/name | 1건 | `AppPlainInput` 승격 |
| alarm | 1건 | `AppSwitch` 신규, BUG-1 가드 |
| trainer-info | 1건 | 골든에 401 리프레시가 섞일 뻔 |
| edit/email | 1건 | **`/auth/validation/` 공개 경로 누락 발견** |
| last-reservation | 1건(쿼리 포함) | `AppMonthPicker` 신규, 시트 둘 |

공용으로 올린 것: `AppPlainInput` · `AppSwitch` · `AppMonthPicker` ·
`AppButton.baseLabel` · `AppLayoutHeader.backgroundColor`.

최종: **Dart 713 통과**(680 → 713, +33), `verify.sh` 4/4,
analyze `No issues found!`. 골든 `mypage-student-last-reservation` 신규.
뮤테이션 M53·M54·M55·M56 전부 기대대로 실패 확인.

---

## 2026-09-16 — S1 `/trainer/manage` (나의 회원): 회원관리 계열의 첫 화면

트레이너 회원관리 19개 중 첫 화면. 서베이(`trainer-manage-survey.md`,
1,825줄)가 먼저 있었고, 그 위에 **픽셀 실측을 한 번 더** 얹었다
(`trainer-manage-s1-measurements.md`, 440×900).

### 서베이 권장 순서를 두 군데 바꿨다

**① Phase 0(공용 위젯 4개 선행)을 건너뛰었다.** 서베이는
`AppBottomSheet`·`AppAlertDialog`·`AppDropdownMenu`·`AppTextarea`를 화면보다
먼저 만들라고 권했다. 이 프로젝트가 실제로 지켜 온 규칙은 **두 번째
사용처가 생길 때 승격**이다 — `AppPlainInput`이 그렇게 나왔고, 반대로
사용처 없이 만든 위젯은 실제 화면을 만나면 모양이 바뀐다. S1의 정렬
드롭다운과 회원추가 다이얼로그는 화면 안 private 위젯으로 두었다. S2 이후가
같은 것을 쓰면 그때 올린다.

**② S14가 아니라 S1부터.** 골든이 이미 잡혀 있었고(`trainer-manage`),
계열의 진입점이며, 사용자가 "첫 화면부터"라고 지정했다.

### 서베이가 클래스명까지 맞았는데도 실측에서 일곱 개가 어긋났다

이번 화면의 가장 큰 교훈이다. 서베이는 웹 소스를 정확히 읽었고 커스텀
스페이싱 스케일도 옳게 환산했는데, 브라우저에서 잰 값은 달랐다.

| 항목 | 계산하면 | 실측 | 왜 |
|---|---|---|---|
| `가입` 배지 높이 | 18 (15 + 1.5×2) | **22.41** | 부모 flex의 `align-items: normal`(stretch)로 형제 이름(22.41)에 맞춰 늘어난다 |
| 드롭다운 항목 간격 | `gap` 있을 것 | **0** | 45짜리 둘이 맞붙는다 |
| `mb-[30%]` | 높이 683의 30% | **120** | 퍼센트 세로 마진은 **포함 블록의 폭**(400) 기준이다 |
| 정렬 트리거 콘텐츠 박스 | 일부 | **0** | `py-[18px]`(36)가 `h-11`(36)과 같아 아이콘·라벨이 오버플로로 그려진다 |
| 다이얼로그 안쪽 폭 | 440 | **438** | shadcn `border` 1px |
| 다이얼로그 `justify-evenly` | 여백 분배 | **무력** | 두 링크가 `w-full`이라 남는 공간이 0이다 |
| 아이콘 크기 | 정사각형 | **비정사각 4개** | `+` 17×16, 정렬 13×14, `alert_circle` 35×36, `people_plus` 25×24 |

배지의 상속 `line-height`가 길이값(24px)이 아니라 **단위 없는 1.5**라는
것도 조상 체인을 전부 재서야 확인됐다(10 × 1.5 = 15).

### 상태가 셋이다 — `undefined` ≠ `null`

웹 `studentList`는 react-query의 `data`라 값이 셋이고, **요청이 실패하면
`null`이 아니라 `undefined`**다.

| `data` | 화면 |
|---|---|
| `undefined` (로딩) | 검색바만. 스피너도 스켈레톤도 없다 |
| `undefined` (**실패**) | `검색 결과가 없습니다.` — `등록된 회원이 없습니다.`가 아니다 |
| `null` (회원 0명) | `등록된 회원이 없습니다.` + `회원 등록하기` |
| `[...]` | 카드 목록 |

`studentList === null`이 거짓이라 실패가 두 번째 칸으로 떨어진다. 에러
분기가 19개 화면 전부에 없는 웹(BUG-13)의 결과다. 화면은 `_received`
플래그로 `undefined`와 `null`을 가른다 — 뮤테이션 M5(실패를 `_received =
true`로)가 이 가드를 지킨다.

**카운트+정렬 행은 세 분기 전부에서 보인다.** 웹에서 그 행은 분기들의
형제라, 회원이 0명이어도 `총 0명`과 살아 있는 드롭다운이 함께 뜬다(M7).

### 옮긴 웹 버그 둘

- **BUG-41 — `가입` 배지가 전원에게 붙는다.** 서버는 `isNonmember`를 보내고
  웹은 `item.nonmember`를 읽는다. 언제나 `undefined`라 `!undefined`가 참이다.
  **서베이는 "사용자 확인 필요"로 남겼지만 이미 선 결정이 답한다** —
  `/student` 홈에서 "웹 버그는 그대로 옮기고 기록한다"로 정했고 아홉 화면에
  일관되게 적용했다. 브라우저 실측에서도 `isNonmember`가 `false`인 회원과
  `true`인 회원이 **둘 다** 배지를 달고 있었다. 모델은 `isNonmember`를
  담되 **화면이 일부러 보지 않는다** — 필드를 지우면 "왜 안 보는가"의
  근거가 사라진다.
- **BUG-22 — 검색어만 소문자가 된다.** `student.name.includes(keyword.toLowerCase())`
  — 대상 이름은 그대로다. `Kim`은 `kim`으로 찾아지지 않고, 첫 글자 `K`가
  들어간 검색어로는 무엇을 쳐도 못 찾는다. `im`처럼 대문자가 없는 조각만
  걸린다.

### 뮤테이션 35개 중 33개를 죽이고, 두 생존자에서 배웠다

**M16 — SVG 크기 단언이 통째로 공허했다.** `emptyIconWidth`를 35 → 36으로
바꿔도 `tester.getSize(SvgPicture)`는 그대로 `Size(35, 36)`을 돌려줬다.
flutter_svg가 안쪽에 `FittedBox` + `SizedBox.fromSize(pictureInfo.size)`를
두는데 `getSize`가 그쪽을 잡는다 — **재고 있던 것은 요청 크기가 아니라
viewBox 고유 크기**였다. 자산의 viewBox와 요청 크기가 같은 동안은 맞아
보이지만 아무것도 지키지 않는다. 위젯의 선언값(`picture.width`)을 직접
읽도록 고쳤고, 그러자 M16·M24(돋보기 20→24)·M25(아바타 32→40)가 전부
잡혔다. → 규율 #20.

**M11 — `CrossAxisAlignment.stretch`가 죽은 코드였다.** 배지 `Container`에
`alignment`가 붙어 있으면 그 자체로 허용된 최대 높이까지 커진다. 즉 두
속성이 서로를 가려서 **어느 쪽을 지워도 테스트가 안 깨졌다**(M11, M26 둘 다
생존). `IntrinsicHeight`는 진짜 필수였다 — 빼니 46건 전부 실패했다(M23).
겹친 둘 중 웹 구조에 더 가까운 `alignment`만 남기고 `stretch`를 지웠더니
M26이 잡혔다. **중복된 두 메커니즘은 서로의 알리바이가 된다.**

**정렬 테스트의 헬퍼도 같은 부류를 품고 있었다.** 카드 이름을
`widgetList`로 모아 `fontWeight == w700`으로 걸렀는데, 그것은 **트리
순서**(깊이 우선)지 화면에 보이는 순서가 아니다. 지금은 `ListView`라 둘이
같지만 보장이 아니다 — y 좌표로 다시 정렬하도록 고치고, **둘이 실제로
같다는 것을 확인하는 테스트**를 따로 뒀다. 정렬은 이 화면의 유일한
비자명 로직이고 두 테스트가 전부 이 헬퍼를 지난다.

### Flutter는 줄 상자 높이를 정수로 반올림한다

`16 × 1.4`가 웹에선 22.4인데 Flutter는 **22.0**, `13 × 1.5`가 웹 19.5인데
Flutter는 **20.0**이다(방향도 일정하지 않다). 그래서 글자가 섞인 치수는
웹 실측과 소수점이 어긋난다 — 이관 오류가 아니다. 배지는 절대값 대신
**`배지 높이 == 이름 높이`**로 단언했고, 다이얼로그는 앱 값 150을 박고
웹 149.5와의 차이를 주석으로 남겼다. → 규율 #21.

### 셸에 붙인 것

- **`AppLayout.scrollable`** — 웹 `<Layout.Contents className='overflow-y-hidden'>`.
  이 화면은 검색바를 고정하고 목록만 스크롤한다. **이때만 `contents` 안에서
  `Expanded`를 쓸 수 있다** — 규율 #12가 금지한 이유(스크롤뷰 안에서 높이가
  무한)가 사라지기 때문이다. 빈 상태 높이 517이 실측과 정확히 맞는 것이
  이 구조가 옳다는 증거다(683 − 36 − 10 − 120).
- **`AppLayoutHeader.trailing`** — 헤더 오른쪽 임의 위젯. `onClose`와 배타.
- **`AppLayoutHeader.titleStyle`** — 웹이 `HEADING_4`(bold)와
  `HEADING_4_SEMIBOLD`를 화면마다 섞어 쓴다. 지금까지 옮긴 아홉 화면을
  grep으로 확인한 결과 전부 semibold라 기본값은 그대로 두고, S1만 bold다.

### 새 계층

`lib/entity/trainer/`(api + model). `MemberApi`와 나눈 기준은 도메인이
아니라 **경로**다 — `/api/v1/trainers/**`는 백엔드 `TrainerController`가
`ROLE_TRAINER`로 막아 둔 요청들이고, 계열 19개 화면이 전부 이 껍데기를 쓴다.
(회원이 부르는 `/members/trainer-mapping/info`는 `MemberApi`에 그대로 둔다.)

### 자산

`search` · `profile_default` · `icon_arrow_down_up` · `icon_close` ·
`people_plus` · `peoples` 여섯 개. **여섯 다 `fill="current"` 함정이
없었고**(규율 #13) 복사 직후 grep으로 확인했다. `plus.svg`는 이미
정규화돼 있었다. 프로브 맵(`assets_test.dart`)에 등록.

최종: **Dart 791 통과**(713 → 791, +78), `verify.sh` 4/4,
analyze `No issues found!`. 골든 `trainer-manage`(GET 1건) 사용.

---

## 2026-09-16 — S2 `/trainer/manage/[memberId]` (회원 정보)

계열 두 번째 화면. 이 화면의 값은 **화면 자체보다 공용 승격 세 건**에 있다.

### BUG-3·BUG-26은 이미 결정돼 있었다

다음 화면을 고를 때 "BUG-3(12월→2월)과 BUG-26(`widht` 오타) 판단이 필요하다"고
적었는데, **둘 다 학생 홈 이관 때 끝나 있었다.**
`StudentPoint.webMonthLabel`에 2026-09-15 결정이 주석으로 박혀 있고,
`CourseCard.arrowSize`에는 "자산도 14×14라 결과가 같다"까지 적혀 있다.
S2는 같은 모델·같은 컴포넌트를 재사용하므로 **다시 물을 일이 아니었다.**
→ 다음에도 "판단 필요"를 적기 전에 기존 주석을 먼저 확인할 것.

### 웹 소스를 기계적으로 대조해 재사용 범위를 확정했다

학생 홈과 S2의 `<CourseCard>` 블록(186줄 vs 198줄)에서 클래스 문자열만
뽑아 다중집합으로 비교했더니 **차이가 둘뿐이었다**:

- S2에 `mb-6`(카드 바깥 여백)이 더 있다
- **학생 홈 포인트 바에는 `h-[54px]`가 있고 S2에는 없다**

그래서 `CourseCard.pointBarHeight`를 nullable로 열었다. null이면 내용이
높이를 정한다 — 실측이 접힘 **54.4** / 펼침 **51.5**로 갈리는 것이 그
증거다(고정이면 둘이 같다). 뮤테이션 M65가 이 차이를 지킨다.

**눈으로 두 파일을 읽는 대신 클래스 집합을 뽑아 비교한 것**이 이 결론을
5분 만에 냈다. 비슷한 블록이 두 화면에 복붙돼 있을 때 쓸 방법이다.

### 공용 승격 세 건 — Phase 0을 건너뛴 판단이 값을 했다

서베이는 `AppDropdownMenu`·`AppAlertDialog`·`AppCheckbox` 등을 화면보다
먼저 만들라고 권했고(Phase 0), S1에서 그것을 건너뛰었다. S2에서 **두 번째
사용처가 생기자 무엇이 같고 무엇이 다른지를 실측으로 알고** 만들 수 있었다.

| 위젯 | 첫 사용처 | 두 번째 | 실측으로 확인한 것 |
|---|---|---|---|
| `AppDropdownMenu` | S1 정렬 | S2 케밥 | **폭과 위치만 다르다** — 패딩 4, 라운드 8, 테두리 `#E2E8F0`, 그림자 `0 4 12 rgba(0,0,0,.16)`, 항목 45, 간격 0, 글꼴 `TITLE_3`가 전부 같다 |
| `AppCheckbox` | 회원 탈퇴 | S2 환불 시트 | 20 / 15×12 / `rounded-sm` / gray300 / primary500 — **상수까지 같다** |
| `showSuccess` | (없음) | S2 환불 삭제 | 에러 토스트와 **아이콘만** 다르다 |

승격 후 S1 테스트 50건이 **그대로 통과**했다 — 기하가 보존됐다는 증거다.

**다이얼로그는 올리지 않았다.** 웹에서 다른 컴포넌트다 — 회원 탈퇴는
shadcn `Dialog`(폭 320, `p-7`, 제목+본문, 버튼 높이가 내용으로 정해짐),
S2는 `AlertDialog`(폭 400, `px-7 py-11`, 제목만 가운데, 버튼 `h-12` 고정).
공통이 라운드와 테두리색뿐이라 합치면 옵션만 늘어난다.

### 공유 DTO를 제자리로 옮겼다 (별도 체크포인트)

`entity/home/model/student_home.dart`가 실은 공유 백엔드 DTO 묶음이었다 —
S2가 11개 선언 중 8개를 쓴다. `Course` → `entity/course/`,
`StudentPoint`/`StudentRank`/`RankTrend` → `entity/point/`,
`HomeDiet`/`DietMeal` → `entity/diet/`, 파일 전용 `_asInt` →
`core/json/json_number.dart`의 `asIntOrNull`. **791 그대로 통과**한 뒤
S2를 시작해서 S2의 diff가 순수하게 남았다.

`HomeDiet`에 `dietId`를 더했다(널 허용). 홈은 안 쓰고 S2만 쓴다 —
`Gym`을 넓히다 홈을 죽인 적이 있어 **`as int`로 못박지 않았다.**

### 상태가 넷인데 화면은 둘로만 갈린다

웹 `{memberInfo && (<><Header/><Layout.Contents/></>)}`가 **헤더까지**
감싼다. 로딩 중에도, 요청이 실패해도 **뒤로가기 버튼조차 없다.**
지난 예약(BUG-9)과 같은 부류라 그대로 옮겼고 M48이 지킨다.

식단은 `{dietId && …}`와 `{dietId === null && …}` 두 조건이 **서로의
반대가 아니다** — `dietId`가 `0`이면 둘 다 안 걸려 식단 자리가 통째로
빈다. 모델 테스트가 네 경우를 전부 고정한다.

### 브라우저에서 못 본 분기가 많다

실측 계정 두 회원이 **둘 다** `ranking: 999` · `nickName: null` ·
`fileUrl: null` · `dietId: null`이었다. 그래서 별칭·구분선·`랭킹 N` 줄은
**높이 0의 빈 컨테이너**로만 확인됐고, 프로필 사진·오늘 식단 3칸·
`수강권 없음` 카드·체크된 체크박스는 보지 못했다. 웹 소스에서 옮기고
`deferred-minors.md`에 디자인 검수 항목으로 남겼다.

구분선 조건이 **`랭킹≠999 && 별칭있음`**(`||`가 아니다)이라는 것은
소스에서만 알 수 있었고, 모델 테스트가 네 경우를 고정한다(M40·M41).

### 실측이 기존 이관과 어긋난 값 — 바꾸지 않고 기록했다

활성 수강권 분기의 포인트 바에서 `point.png`가 **18.84**로(속성은 21),
화살표 svg 박스가 **29.73**으로(`width="current"` + `widht` 오타) 측정됐다.
같은 markup을 쓰는 **학생 홈의 `CourseCard`는 21/14로 이관돼 있다.**
다만 만료 분기에서는 같은 아이콘이 정확히 21로 측정돼, 이 값들이
markup이 아니라 **분기·데이터에 딸린 것일 가능성**을 배제할 수 없다
(실측 계정의 `monthPoint`가 한 자리였다). 출고된 코드를 단일 측정으로
바꾸는 대신 `deferred-minors.md`에 재측정 항목으로 남겼다.

### 뮤테이션 24개 전부 격추 — 생존자 셋이 전부 진짜 구멍이었다

- **M60** 알럿 폭 상한 400을 지워도 통과했다. 440 뷰포트에서는
  `insetPadding` 20이 이미 400으로 깎기 때문이다 — **넓은 화면에서만
  드러난다.** 900 뷰포트 테스트를 추가하니 잡혔다.
- **M65** 포인트 바를 고정 높이로 바꿔도 통과했다. 높이를 재는 단언이
  없었다 — 접힘/펼침 높이가 **달라야 한다**는 단언으로 잡았다.
- **M66** 성공 토스트를 에러 토스트로 바꿔도 통과했다. 문구만 봤기
  때문이다 — **아이콘**(`check.svg` vs `error.svg`)을 함께 단언해 잡았다.

셋 다 "값은 맞게 썼는데 그것을 확인하는 단언이 없던" 경우다.

최종: **Dart 863 통과**(791 → 863, +72), `verify.sh` 4/4,
analyze `No issues found!`. 골든 `trainer-manage-member`(GET 1건) 신규.

#### 마감 리뷰에서 고친 것 셋

- **식단 타일의 첫 칸 판정을 인덱스로 바꿨다.** `meal != diet.breakfast`는
  `DietMeal`에 `==` 오버라이드가 없어서 **동일성 비교**로 동작한다. 지금은
  `meals`가 같은 인스턴스를 돌려주니 맞지만, 누가 값 동등성을 추가하는
  순간 빈 끼니 셋이 서로 같아져 간격이 통째로 어긋난다 — 터지지 않고
  조용히 틀린다. `indexed`로 세면 그 함정이 사라진다.
- **바로가기 열의 탭 영역 폭을 단언으로 고정했다.** 기존 테스트는
  `find.text(...)`를 눌러서 **카드 전체가 눌려도 통과**했다. 웹 `<a>`는
  내용 크기(48.03)이고 열 사이 ~103px은 링크가 아니다. 열과 열 사이를
  `tapAt`으로 누르고 `navigated`가 비어 있는지, 그리고 GestureDetector
  폭이 글자 폭과 같은지 둘 다 단언한다. 열에 폭 110을 주는 뮤테이션으로
  격추를 확인했다.
- **`point.png` 18.84 / 화살표 29.73 재측정 항목에 가설을 적어 뒀다.**
  만료 바는 `<div>`, 활성 바는 `<button>`이다 — 차이가 데이터(자릿수)가
  아니라 **`<button>`에 걸리는 브라우저 기본 스타일**일 수 있다. 참이면
  데이터와 무관하게 재현되고 학생 홈에서도 같은 값이 나온다. 재측정이
  무엇부터 확인해야 하는지를 남겨야 다음 사람이 처음부터 헤매지 않는다.

---

## 2026-09-18 — S3 `/trainer/manage/[memberId]/course-history` ({name}님 수강권)

웹 라우트 **21/73**. 회원관리 계열 3/19. Dart 908 테스트, `verify.sh` 4/4.
실측 전문은 `docs/trainer-manage-s3-measurements.md`.

### 서베이가 틀렸던 두 가지 — 실측이 아니었으면 그대로 옮겼다

**① 헤더 `+`의 조건.** 서베이는 "만료일 때만 렌더"라고 적었다. 소스를 보면
조건이 `course?.totalLessonCnt === course?.completedLessonCnt`인데,
**수강권이 없으면 양변이 `undefined`라 참**이다. 로딩 중에도 `historyData`가
없어 같은 결과다. 즉 **만료 · 수강권없음 · 로딩중 셋 다** `+`가 뜬다.
앱은 `course == null || course.isExpired` 한 줄로 옮겼고, 이 한 줄이
`_showRegisterAction`의 전부다. 뮤테이션 M1(`!= null && ...`)이 두 테스트로
잡힌다 — 그중 하나가 "로딩 중에도 뜬다"라서, 가드가 아니라 **시점**을
겨누는 테스트가 필요했다.

**② 빈 목록의 모양.** 웹 타입이 `content: CourseHistoryItem[] | null`이고
화면도 `content === null`을 가드해서 서베이가 null을 전제로 적었는데,
**실서버는 `[]`를 준다**(실측). 양쪽 다 파싱하게 만들었다. 규율 #16이
말하는 "선언이 아니라 실측"의 또 다른 사례다.

**와이어 키 `isLast`는 맞았다.** Java `boolean isLast`의 빈 게터가 `last`로
직렬화되는 함정이 있어 의심했는데 실제 응답이 `isLast`였다. 모델 테스트가
**`last`로는 읽히지 않는다**까지 고정한다 — 맞았다는 것도 근거를 남겨야
다음 사람이 다시 의심하지 않는다.

### 골든 캡처가 401을 먹을 뻔했다

첫 진입 캡처가 `401 → POST /auth/refresh-token → 재요청` **3건**이었다.
토큰이 만료된 상태였기 때문이다. 그대로 골든을 떴으면 앱에는 401 리프레시가
없으니 위젯 테스트가 **매번 2건 누락**으로 떨어졌을 것이고, 원인이 화면이
아니라 캡처 순간의 토큰 상태라는 걸 알아채기 어려웠을 것이다. 토큰이 갱신된
뒤 다시 진입해 1건짜리를 캡처했다. `har/README.md`에 재캡처 주의로 적었다.

부수 소득으로 **웹의 401 경로를 실제로 봤다.** `next-steps.md` §5는 웹이
"갱신 후 원 요청을 재시도하지 않는다"고 적어 뒀는데, 실측에서는 재시도가
나갔다(인터셉터가 아니라 React Query 쪽으로 보인다). 401 리프레시를 옮길 때
이 실측을 근거로 다시 판단할 것.

### 승격 판단 — 하나는 합치고 하나는 안 합쳤다

**시트는 합쳤다.** 등록 시트와 추가 시트를 **각각 재 보니** 420×233.4,
패딩 24/20/28/20, 입력 100×57, 버튼 380×52까지 완전히 같고 **제목과 버튼
문구 둘만** 달랐다. 파라미터 둘짜리 사설 위젯 하나로 충분하다.

**알럿은 안 합쳤다.** 처음엔 S2 알럿과 같은 상자로 보였는데 — 실제로
폭 400·패딩 36/20·라운드 8·제목~버튼 34·버튼 48·간격 8이 전부 같다 —
**버튼이 갈린다**:

| | S2 `Header.tsx` | S3 `StudentCourseDetailPage.tsx` |
|---|---|---|
| 버튼 글꼴 | `TITLE_1_SEMIBOLD` 16/22.4/**600** | `text-base font-normal` 16/**24**/**400** |
| 버튼 행 | `flex flex-row gap-3` → **175.55 / 174.45** | `grid grid-cols-2 gap-3` → **175 / 175** |

공용으로 올리면 글꼴과 폭 분배를 옵션으로 받아야 한다. 회원 탈퇴 `Dialog`를
합치지 않은 것과 같은 기준으로 **세 번째 알럿도 사설로 뒀다.** 네 번째가
생기면 상자만 올리는 것을 재검토한다.

**`CourseCardHeader`·`CourseCardContent`는 공개했다.** 웹도 `CourseCard`를
컨테이너로 두고 이 둘을 조합한다 — 학생 홈·S2는 포인트 바까지 넣고, S3는
둘만 쓴다. 기존 `CourseCard`의 동작은 건드리지 않았다.

### BUG-9은 도달 불가로 판정했다

웹 `studentCourseId = Number(course?.courseId)`는 수강권이 없으면 `NaN`이고,
서베이는 이것을 BUG-9으로 적었다. Dart에는 `NaN` 정수가 없어서 "대응물을
무엇으로 할까"가 문제였는데 — **그 값을 쓰는 두 버튼이 `course &&` 분기
안에만 있다.** 수강권이 없을 때 눌리는 것은 `courseId`가 없는 등록(POST)뿐.
**웹에서 도달할 수 없는 경로에 Dart 대응물을 만들면 웹에 없는 동작이 된다.**
만들지 않고 이 판정을 화면 주석에 남겼다.

### 시트 높이를 맞춘 것은 1px 테두리였다

시트 패널 높이가 실측 **233.4**인데 내용만 더하면 232.4다
(24 + 23.4 + 24 + 57 + 24 + 52 + 28). 남는 1은 shadcn `SheetContent
side='bottom'`의 **`border-t`**였다. 눈에 거의 안 보이는 선이지만 넣어야
높이가 맞는다 — **소수점이 안 맞을 때 테두리를 먼저 의심할 것**(S1에서
다이얼로그 안쪽 폭이 440이 아니라 438이었던 것과 같은 부류다).

닫기 X도 같은 자리에서 나왔다. 제목(671.6)보다 **4 위**(667.6)에 있어서
제목 행에 Row로 넣으면 위치가 어긋나고 제목 폭까지 줄어든다 — 웹이
`absolute right-7 top-7`이라 Flutter에서도 `Stack` + `Positioned`다.
S2 환불 시트는 웹 마크업이 실제로 한 줄이라 Row가 맞았다. **같은 "시트
우상단 X"라도 웹 마크업을 봐야 한다.**

### 실측하지 못한 것

**수강권 없음 분기**(`py-[88px]` + 등록 버튼)를 브라우저에서 못 띄웠다 —
이 트레이너의 회원이 둘뿐이고 **둘 다 수강권이 있다.** 수강권 없는 회원을
만들려면 회원 추가(뮤테이션)가 필요해서 하지 않았다. 웹 소스에서 읽은 값으로
옮기고 **상수 주석과 실측 문서에 "미실측"으로 표시**했다. 무한스크롤 2페이지도
같은 이유로(최대 내역 4건) 실측 못 했고 계약 테스트가 요청 모양을 고정한다.

### 규율 #13에 또 걸렸다

빈 상태 아이콘 `notification.svg`가 `stroke="current"`였다. 그대로 들여왔으면
**한 획도 안 그려지고** `assets_test`는 통과했을 것이다(규율 #8의 맹점).
`currentColor`로 정규화해 이식하고 화면이 `SvgTheme(currentColor:)`로
웹의 `stroke='var(--gray-300)'`를 주입한다.

### 환경 — `flutter test`가 Xcode 라이선스로 막혔다

이 머신의 Xcode 라이선스가 미동의라 `xcrun`이 stdout을 비우고,
`objective_c` 네이티브 빌드 훅이 `Bad state: No element`로 죽어 **테스트가
한 개도 실행되지 않았다.** 레포 문제가 아니다(`pubspec.lock` 무변경).
정식 해결은 `sudo xcodebuild -license accept`. 이번에는 PATH 앞에
`DEVELOPER_DIR=/Library/Developer/CommandLineTools`를 export하는 `xcrun`
shim을 두어 돌렸다 — **`DEVELOPER_DIR`만 export하면 flutter가 훅 하위
프로세스에 넘기지 않아 듣지 않는다.**

---

## 2026-09-18 — S4 `/trainer/manage/[memberId]/point-history` ({name}님 포인트)

웹 라우트 **22/73**. 회원관리 계열 4/19. Dart 947 테스트, `verify.sh` 4/4.
실측 전문은 `docs/trainer-manage-s4-measurements.md`.

### 서베이가 "S3와 동일 형태"라고 적은 화면인데 셋이 달랐다

**① 요청이 3건이고, 순서가 추론과 반대였다.** 서베이는
`trainers/members` → `point` → `trainer-mapping`으로 추론하고 **`(추론)`**을
달아 뒀는데, 실제 순서는 **`trainer-mapping`이 1번**이다. 그것도 화면 본체가
아니라 **학생 하단바**가 쏜다(BUG-1 — 트레이너 화면인데 `type='student'`).
두 번 캡처해 같은 결과를 봤다.

학생 홈에서 이미 밟은 함정이다(네비가 화면보다 먼저 쏜다). Flutter는 부모
`initState`가 먼저라 그대로 두면 뒤집히므로 같은 해법(`addPostFrameCallback`)을
썼다. **뮤테이션 M10**(그 한 줄 제거)이 골든과 순서 테스트 둘 다로 잡힌다.

**② BUG-14는 버그가 아니었다.** 서베이가 "`text-blue-100`은 config에 없어
클래스가 생성되지 않는다"고 적었는데 실측 색이 `rgb(219,234,254)` —
Tailwind 기본 `blue-100`(#DBEAFE)이다. `tailwind.config.js`의 `colors.blue`가
**`theme.extend` 안**이라 기본 팔레트를 덮어쓰지 않고 병합하기 때문이다.

**규율 #5가 스페이싱에 대해 이미 말한 규칙이다** — "`theme.extend` 안이라
목록에 없는 키는 Tailwind 기본값이 그대로 산다." 서베이가 스페이싱에는
적용했는데 색에는 적용하지 않았다. **같은 config, 같은 규칙인데 한쪽만
봤다는 뜻이라 다른 색 관련 버그 항목도 의심해야 한다.**

**③ 내역 날짜의 굵기가 다르다.** S3는 `BODY_4_MEDIUM`(500), S4는
`BODY_4`(400). 항목 높이(87)·패딩·라벨·증감은 전부 같은데 이것만 다르다.
"동일 형태"를 믿고 `_HistoryTile`을 공유했으면 **굵기가 틀린 채 테스트까지
통과**했을 것이다.

### 헤더 X — 세 가지가 전부 예상과 달랐다

1. **뒤로가기가 아니다.** 웹 `<Link href='./'>`가 현재 경로의 디렉터리로
   해석돼 `/trainer/manage/6`(회원 정보)로 간다. 눌러서 확인했다.
   그래서 앱도 `pop`이 아니라 **go**다 — 어디서 들어왔든 S2로 간다.
2. **링크 폭이 400인데 제목 자리는 안 눌린다.** 제목이 링크 뒤에 선언돼
   위에 그려지고 포인터를 가로챈다. playwright가 링크 가운데를 클릭하려다
   `<h2 …> intercepts pointer events`로 **실패해서** 드러났다 — 처음엔
   rect가 겹치니 "제목을 눌러도 이동한다"고 적었다가 정정했다.
   **rect가 겹친다고 눌리는 것이 아니다.**
3. **Flutter는 저절로 같게 동작한다.** 웹 동작을 옮기려고 제목을
   `AbsorbPointer`로 감쌌는데, **뮤테이션이 그 위젯을 통과시켰다** — 빼도
   테스트가 그대로 통과했다. 확인해 보니 `Stack`이 뒤 자식부터 히트
   테스트하고 `Text`가 자기 영역에서 히트를 보고한다(직접 측정: 제목 탭 0회 /
   X 자리 탭 1회). 불필요한 위젯이라 걷어냈다.

   **"뮤테이션이 안 잡힌다"가 항상 테스트 탓은 아니다** — 이번엔 코드가
   불필요했다는 신호였다. 규율 #11은 "가드가 아니라 테스트를 의심하라"인데,
   여기서는 셋째 가능성(가드 자체가 군더더기)이 답이었다. 대신 **순서를
   뒤집는 뮤테이션**은 잡히므로 테스트는 그대로 값을 한다.

### 페이징 봉투를 공용으로 올렸다

S3와 S4의 응답 봉투가 완전히 같았다 — `content`·`pageNumber`·`pageSize`·
`totalPages`·`totalElements`·`isLast`·`mainData`이고 **`mainData`의 내용만**
다르다(S3 `{course, gymName}` / S4 `{searchDate, monthPoint, totalPoint}`).
두 번째 사용처가 생겨 `core/json/paged_response.dart`로 올렸고
(`asIntOrNull`이 그렇게 만들어진 것과 같은 경로), 두 화면이 그것을 쓴다.

거기 담긴 판단 둘을 테스트가 못박는다: **와이어 키는 `isLast`**이고
(`last`로는 읽히지 않는다), **없으면 true**다(false면 다음 페이지를 영원히
조른다). 계열에 페이징 화면이 넷 더 남아 있다(S5·S8·S16·S18).

### `mainData`가 학생 홈의 모델과 같았다

포인트 `mainData`가 `{searchDate, monthPoint, totalPoint}`인데 이것이
학생 홈이 쓰는 `StudentPoint`와 **같은 모양**이다. 그래서 BUG-3
(`webMonthLabel` — 10·11·12월이 0·1·2월이 되는 웹 버그)의 구현과 결정이
그대로 재사용됐다. 새 화면에서도 12월이 `2월 활동 포인트`로 나오는 것을
단언으로 고정했다.

### 뮤테이션 원복이 한 번 막혔다 — 치환 결과가 파일에 이미 있었다

`'${point?.monthPoint ?? 0}'`를 `'${point?.totalPoint ?? 0}'`로 바꾸는
뮤테이션을 넣었는데, **그 문자열이 같은 파일에 이미 있었다**(누적 값 줄).
원복하려고 역치환하려니 대상이 2곳이라 유일성 검사에 걸렸고, 파일이
**뮤테이션된 채로 남았다.**

행 번호로 그 한 줄만 되돌려 복구했고(`git checkout` 금지 — 커밋 전 작업까지
날아간다), 이후에는 **치환 결과가 파일에 존재하지 않는 형태**로 뮤테이션을
잡았다(`+ 1`을 붙이는 식). 규율 #6의 "역치환" 절차에 딸린 전제다:
**뮤테이션 대상뿐 아니라 치환 결과도 유일해야 한다.**

더 안전한 방식도 같이 확인했다 — 원본 전체를 문자열로 들고 있다가 그대로
다시 쓰는 것. 부분 치환보다 실패 지점이 적다.

---

## 2026-09-18 — S5 `/trainer/manage/[memberId]/reservation` ({name}님 예약 내역)

웹 라우트 **23/73**. 회원관리 계열 5/19. Dart 971 테스트, `verify.sh` 4/4.
실측 전문은 `docs/trainer-manage-s5-measurements.md`.

### 새 웹 버그 — `twSelector`가 만든 클래스는 CSS가 생성되지 않는다

활성 탭이 `HEADING_5`(600)로 보여야 하는데 **실측이 400**이었다. 원인은
`shared/utils/tw-utils.ts`:

```ts
export const twSelector = (pseudo, target) =>
  target.split(' ').map((str) => `${pseudo}:${str}`).join(' ');
```

`twSelector('data-[state=active]', HEADING_5)`는 **런타임에**
`data-[state=active]:font-semibold`를 조립한다. Tailwind JIT은 **소스 파일에서
완성된 클래스 문자열을 스캔**하므로 이 문자열을 본 적이 없고, CSS를 만들지
않는다.

**증거가 한 버튼 안에 있다.** 같은 `className`의
`data-[state=active]:bg-primary-500 data-[state=active]:text-white`는 소스에
**리터럴로** 적혀 있어서 정상 동작한다 — 실측에서 배경과 글자색은 바뀌는데
굵기만 안 바뀐다. 리터럴은 되고 런타임 조립은 안 되는 것이 이 버그의 모양이다.

`twSelector`는 9개 파일에서 쓰인다(이미 이관한 S1 `StudentList`와 입력
컴포넌트 포함). 다행히 나머지 8곳은 전부 `twSelector('placeholder', BODY_1)`
형태이고, **입력 자체에 같은 타이포가 이미 걸려 있어 placeholder가 그것을
상속하므로 시각적 차이가 없다.** 실제로 드러나는 곳은 S5 활성 탭 하나다.

> **S4의 BUG-14와 정확히 짝이다.** 거기서는 서베이가 "클래스가 생성되지
> 않는다"고 적었는데 **틀렸고**(`theme.extend`라 Tailwind 기본값이 살아
> 있었다), 여기서는 **맞다**(런타임 조립이라 스캔이 안 된다).
> **Tailwind가 무엇을 만들고 안 만드는지는 소스를 읽어 추론하지 말고 재라.**

### 노쇼 동사를 양방향 계약 테스트로 묶었다

`DELETE /schedule/no-show/{id}` = 노쇼 **처리**, `POST` = **해제**다.
"DELETE니까 삭제/해제"라고 짐작하면 정반대로 동작하고, **화면에서는 성공
토스트까지 정상으로 보인다**(서버가 200을 준다). 그래서 두 방향을 각각
단언하고 **동사를 뒤집는 뮤테이션(M19)**으로 확인했다 — 두 테스트가 함께
깨진다. 이 계열에서 가장 사고나기 쉬운 자리다.

### 예약 카드를 공용으로 올렸다 (세 번째 사용처)

회원 지난 예약 화면의 카드와 **치수가 전부 같았다** — 패딩 `px-6 py-7`(16/20),
라운드 12, 날짜 `TITLE_3` gray-600, `gap-y-2`(6), 시간 `TITLE_1_BOLD` black,
오른쪽 슬롯 `ml-2`(6). 웹도 같은 마크업이다.

`feature/schedule/ui/reservation_card.dart`로 올리고 **오른쪽 슬롯만
파라미터**로 받는다: 지난 예약은 `ReservationStatusBadge`, 트레이너
"다가오는 예약"은 체크 아이콘. 회원 화면을 전환한 뒤 그 화면 테스트 27개가
**한 줄도 안 고치고 통과**했다(그 테스트들이 배지 상수를 참조하지 않았던 것이
운이 좋았다 — 옮기기 전에 참조 수를 먼저 셌다).

**시트는 합치지 않았다.** 회원 쪽은 `pt-[48px]`에 버튼이 `확인` 하나이고,
S5는 `pt-7`(20)에 X가 제목 줄 오른쪽이며 버튼이 둘이다(실측). 알럿 때와 같은
기준이다.

### 제목이 통째로 사라지는 화면

웹이 `{name && `${name}님 예약 내역`}`이라 쿼리 `name`이 없으면 `님 예약 내역`
조차 안 나온다(실측: h2가 **0×0**). S2가 `?name=`을 붙여 링크하므로 정상
경로로는 늘 채워지지만, 딥링크로 들어오면 제목 없는 화면이 된다.

그대로 옮겼고 **`app_test`가 이 화면의 도착을 제목이 아니라 탭 라벨로**
확인한다 — 제목으로 확인하려다 그 자리가 비어 있다는 걸 테스트가 먼저 알려줬다.

### 빈 목록의 모양이 엔드포인트마다 다르다

S3·S4의 페이징 응답은 `content: []`였는데, 예약 응답은 **`reservations: null`**
이다(빈 배열이 아니다). 같은 백엔드인데 다르다 — 회원 지난 예약 모델이 이미
그 차이를 문서화해 두고 있어서 **모델을 그대로 재사용**할 수 있었다.
**"빈 목록은 이 모양"이라고 일반화하지 말 것.**

### "미실측"은 문서에만 적으면 절반이다 — 테스트도 그 분기를 잡아야 한다

S5에는 실측하지 못한 분기가 둘 있었다(다가오는 예약 카드 · 시트의 미출석
분기). 상수 주석에 **미실측**이라고 적어 두긴 했는데, **테스트가 그 분기를
한 번도 렌더하지 않았다.** 즉 소스에서 옮긴 값이 *실행된 적조차 없는* 코드로
남아 있었다 — 오타가 있어도 아무도 모른다.

빈 상태만 그리는 픽스처가 원인이었다(`upcoming`을 null로 두었고, 지난 예약
데이터가 전부 `COMPLETED`였다). 두 분기에 픽스처를 넣어 테스트를 추가하고
뮤테이션으로 확인했다(체크 아이콘 17→20, 오른쪽 슬롯을 배지로 교체, 시트
버튼 색 분기 제거 — 셋 다 잡힌다).

**규칙으로 정리하면:** 실측하지 못한 분기는 ① 문서에 미실측으로 적고
② **테스트로 한 번은 렌더시킨다.** ②가 없으면 나중에 실측 기회가 생겼을 때
무엇을 비교해야 하는지도 남지 않는다.

> 뮤테이션을 만들 때 주의: 컴파일이 깨지는 변형은 "잡힘"으로 보이지만
> **신호가 아니다.** M25를 처음에 없는 파라미터로 만들었다가 컴파일 실패로
> 통과 판정을 받을 뻔했다 — 뮤테이션은 **컴파일되는 형태**여야 한다.
