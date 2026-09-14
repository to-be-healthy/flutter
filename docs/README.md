# 문서

건강해짐 React(Next.js) → Flutter 마이그레이션 기록.

## 여기서 시작

| 파일 | 언제 읽나 |
|---|---|
| **[next-steps.md](next-steps.md)** | **다음에 무엇을 할지.** 새 세션은 이 파일부터 읽는다 — 남은 화면 69개, 공용 컴포넌트 갭, 인프라 갭, 지켜야 할 규율 10개 |
| [progress.md](progress.md) | **왜 그렇게 결정했나.** 시간순 원장. 특정 코드가 왜 그 모양인지 궁금할 때 |
| [../har/README.md](../har/README.md) | HAR 캡처 → 패리티 골든 생성 절차. 화면을 옮길 때마다 본다 |

## 그 외

| 파일 | 내용 |
|---|---|
| [deferred-minors.md](deferred-minors.md) | Phase 0 리뷰에서 이월한 minor 항목 (일부는 이미 해결됨) |
| [next-screens-survey.md](next-screens-survey.md) | **낡음** — 6개 화면 후보 실측표. 여기서 고른 작업은 이미 끝났다 |
| `task-*-brief.md` / `task-*-report.md` | Phase 0 태스크별 지시서와 결과 보고 (9개 태스크). 특정 기반 작업의 상세가 필요할 때만 |
| `task5-contract-excerpt.md` | 백엔드 OpenAPI 계약 발췌 |
| `final-fix-report.md` | Phase 0 최종 리뷰 fix 루프 |
| `screenshots/` | 01~07. 원장의 픽셀 실측 수치가 어디서 나왔는지 추적용 |

## 이 폴더에 없는 것

Phase 0 리뷰에 썼던 `.diff` 17개는 옮기지 않았다. 커밋 사이의 `git diff`라
`git diff <sha>..<sha>`로 재생성되고, 백엔드 OpenAPI 예시 자격증명을 품고 있다.
원본은 `.superpowers/sdd/2026-09-13-flutter-migration-phase0/`에 남아 있다
(gitignore 대상이라 커밋되지 않는다).
