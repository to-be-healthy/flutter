# Phase 0 deferred minor — 최종 리뷰 triage 대상

각 항목은 태스크 리뷰에서 Minor로 분류되어 fix 루프에 넣지 않고 이월한 것이다.
최종 whole-branch 리뷰는 이 목록을 보고 **머지 전에 반드시 고쳐야 할 것**을 골라야 한다.

- Task 1: minor (deferred): lib/main.dart의 `Colors.deepPurple`가 "리터럴 금지" constraint 위반 — flutter create 보일러플레이트이며 Task 9가 main.dart를 교체하면서 자동 해소됨. 최종 리뷰에서 확인할 것.
- Task 2: minor (deferred): AppColors/AppRadius의 `lerp()`에 테스트 없음(AppSpacing.lerp만 테스트됨). 브리프가 요구하지 않았고 형태가 동일한 보일러플레이트라 위험 낮음. 최종 리뷰에서 triage.
- Task 2: minor (deferred): 리뷰어가 `lerpDouble`의 `dart:ui` 충돌 가능성을 명명된 리스크로 점검 → non-issue 확인(해당 파일은 material.dart만 import, 클래스 static 멤버가 우선 해소). 조치 불필요.
- Task 3: minor (deferred): `AppTypography.all`이 수동 유지 목록이라 새 스타일 추가 시 fontFamily 테스트 커버리지가 조용히 빠질 수 있음. 현재는 동기 상태. 주석 추가 권고.
- Task 3: minor (deferred): `AppTheme.textTheme` 슬롯 매핑(titleMedium 등)에 테스트 없음 — 인접 슬롯 간 copy-paste 오류를 못 잡음. 화면이 주로 AppTypography.*를 직접 참조하므로 위험 낮음.
- Task 4: minor (deferred): "예상치 못한 추가 키"의 값이 중첩 맵이면 그 안쪽 비밀은 마스킹되지 않음(최상위 키만 ***). fix 이전보다는 개선됨.
- Task 4: minor (deferred): 리스트-of-맵 안쪽 마스킹/비교는 여전히 리프 jsonEncode — Python mask()와 비대칭.
- Task 4: minor (deferred): verify.sh가 python3를 하드 요구 — CI에 python3 없으면 파이프라인 정지.
- Task 5: minor (deferred): `sign_in_response.dart`의 개별 필드 캐스트가 가드되지 않음 — data는 있는데 개별 키가 없거나 타입이 다르면 진단 가능한 FormatException이 아니라 raw TypeError가 난다. plan-mandated(브리프 코드 그대로).
- Task 5: minor (deferred): 스냅샷 대조 테스트가 "login 경로 존재"만 확인 — 백엔드 필드 rename/삭제를 못 잡는다. plan-mandated, 리포트 §7.2에 이미 공개됨.
- Task 6: minor (deferred): `flutter pub remove`가 pubspec.yaml의 안내 주석 2줄을 지움 — 기능·구조 영향 없음(cosmetic).
- Task 6: minor (deferred): 리포트 산문이 path_provider_foundation을 "linux/windows 전이 의존"이라 기술했으나 실제로는 Darwin(macOS/iOS) federated 구현 — 문서 뉘앙스만, SDK 하한 결론에는 영향 없음.
- Task 7: minor (deferred, fix diff가 도입): `app_text_input.dart:70-75`의 `border:` 필드가 `enabledBorder`에 가려져 실질 도달 불가 — 값이 동일해 동작 버그는 없으나 finding #1과 같은 성격의 죽은 분기가 약한 형태로 재도입됐다. **62번 복사되기 전 정리 권고**(border: 제거 또는 고정값). 최종 리뷰에서 triage.
- Task 7: minor (deferred, out-of-scope): 비활성 primary가 gray300 배경에 흰 텍스트라 대비가 낮다 — 웹 parity 지시대로이므로 재론 대상 아니나, 향후 시각·접근성 패스에서 확인 필요.
- Task 7: minor (deferred, out-of-scope): `backgroundKeyFor(label)`이 라벨만 쓰므로 같은 라벨 버튼이 한 화면에 둘이면(중첩 다이얼로그의 "확인" 등) 다시 충돌한다. 컨트롤러 지시에 내재된 한계이며 Phase 1 이후 이 패턴을 채택하는 태스크가 인지해야 함.
