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
