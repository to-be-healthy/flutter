#!/usr/bin/env bash
# 웹 원본 대비 Flutter 구현의 줄 수 팽창률을 측정한다.
#
# 단순 `wc -l` 비율 하나만 내면 두 가지 편향이 서로 반대 방향으로 섞여
# 어느 쪽으로 얼마나 틀렸는지 알 수 없다:
#   (1) 웹 원본에는 Flutter가 **의도적으로 생략한** 기능(로고·회원가입 버튼·
#       찾기 링크·라우팅·웹뷰 브리지)이 들어 있다 → 분모가 커져 팽창률을 **과소**평가.
#   (2) Flutter 쪽은 Task 7·8이 세운 "토큰 예외는 코드에 이유를 남긴다" 규율
#       때문에 주석이 두껍다 → 분자가 커져 팽창률을 **과대**평가.
#
# 그래서 4개 기준을 모두 출력하고, **단일 수치가 아니라 밴드로** 보고한다:
#   ④ code↔code = 작업량 proxy (하한)   ② raw↔raw = 예상 파일 볼륨 (상한)
# 그 폭은 "얼마나 주석을 달 것인가"라는 팀의 문서화 예산 선택이지
# 마이그레이션이 유발하는 비용이 아니다.
set -euo pipefail

WEB=/Users/seonwoo_jung/workspace/personal/tobehealthy/frontend
FLUTTER=/Users/seonwoo_jung/workspace/personal/tobehealthy/flutter

python3 - "$WEB" "$FLUTTER" << 'EOF'
import sys
from pathlib import Path

web_root, flutter_root = Path(sys.argv[1]), Path(sys.argv[2])

# 웹 원본과, Flutter가 생략해 대응 코드가 없는 줄 번호 구간(1-based, 양끝 포함).
# 구간은 사람이 원본을 읽고 확정한 값이다. 원본이 바뀌면 아래 expected_lines
# 검사가 먼저 걸리므로, 그때 구간을 다시 확인할 것.
WEB_FILES = [
    {
        "path": web_root / "src/page/public/ui/SignInPage.tsx",
        "expected_lines": 59,
        "omitted": [
            ((6, 6), "IconBack·IconLogo import — SVG 자산은 Phase 2"),
            ((8, 8), "Button·Separator import — 뒤로가기 버튼·구분선 전용"),
            ((14, 14), "const router = useRouter() — 라우터 부재"),
            ((30, 32), "뒤로가기 버튼(router.push('/')) — 라우터 부재"),
            ((36, 38), "로고 블록(IconLogo 64x64) — SVG 자산은 Phase 2"),
            ((40, 54), "비밀번호 찾기 / 아이디 찾기 링크 — 라우터 부재"),
        ],
    },
    {
        "path": web_root / "src/feature/auth/ui/SignInForm.tsx",
        "expected_lines": 118,
        "omitted": [
            ((1, 1), "next/link import — 회원가입 링크 전용"),
            ((13, 13), "const router = useRouter() — 라우터 부재"),
            ((29, 37), "onSuccess 본문(토큰 저장·웹뷰 브리지·라우팅) — Phase 1"),
            ((105, 114), "회원가입 버튼(outline) — 라우터 부재"),
        ],
    },
]

FLUTTER_FILE = flutter_root / "lib/page/public/sign_in_page.dart"

# 참고 데이터포인트 — Task 7·8이 만든 웹↔Dart 쌍.
# **1:1 대응이 아니므로 평균 내지 말 것.** caveat을 각 행에 함께 출력한다.
REFERENCE_PAIRS = [
    (["src/shared/ui/button.tsx"], "lib/shared/ui/app_button.dart",
     "웹이 cva로 나눈 variant 3개를 한 위젯에 접어넣음"),
    (["src/widget/layout.tsx"], "lib/widget/app_layout.dart",
     "웹 3슬롯 + 화면별 반복 헤더를 표준 헤더로 승격"),
    (["src/shared/ui/input/TextInput.tsx", "src/shared/ui/input/Input.tsx"],
     "lib/shared/ui/app_text_input.dart",
     "웹 입력 컴포넌트 5종(Email/Password/Otp 등) 중 1종만 덮음"),
]

# 웹 전체 UI 줄 수(MOBILE_MIGRATION_ANALYSIS.md §2 실측) 및 그중 shared/ui 비중.
TOTAL_WEB_UI_LINES = 22257
SHARED_TSX_LINES = 2285


def classify(line: str) -> str:
    s = line.strip()
    if not s:
        return "blank"
    if s.startswith("//") or s.startswith("/*") or s.startswith("*"):
        return "comment"
    return "code"


def counts(lines) -> dict:
    out = {"raw": len(lines), "code": 0, "comment": 0, "blank": 0}
    for line in lines:
        out[classify(line)] += 1
    return out


web_total = web_kept = web_kept_code = web_total_code = 0
web_comment = web_blank = 0
detail = []

for spec in WEB_FILES:
    lines = spec["path"].read_text(encoding="utf-8").splitlines()
    if len(lines) != spec["expected_lines"]:
        sys.exit(
            f"원본이 바뀌었다: {spec['path'].name} "
            f"기대 {spec['expected_lines']}줄, 실제 {len(lines)}줄\n"
            "생략 구간(omitted)을 다시 확인하고 이 스크립트를 갱신하라."
        )

    omitted_idx = set()
    for (start, end), _reason in spec["omitted"]:
        omitted_idx.update(range(start - 1, end))

    c = counts(lines)
    web_total += c["raw"]
    web_total_code += c["code"]
    web_comment += c["comment"]
    web_blank += c["blank"]

    kept = [line for i, line in enumerate(lines) if i not in omitted_idx]
    web_kept += len(kept)
    web_kept_code += counts(kept)["code"]
    detail.append((spec["path"].name, c["raw"], len(omitted_idx), spec["omitted"]))

flu = counts(FLUTTER_FILE.read_text(encoding="utf-8").splitlines())
flutter_total, flutter_code = flu["raw"], flu["code"]

print("== 참조 화면: SignInPage + SignInForm → sign_in_page.dart ==")
print()
for name, total, omitted, ranges in detail:
    print(f"  {name}: {total}줄 (생략 대응 {omitted}줄)")
    for (start, end), reason in ranges:
        span = f"L{start}" if start == end else f"L{start}-{end}"
        print(f"      {span:<10} {reason}")
print(f"  합계 {web_total}줄 / 생략 제외 {web_kept}줄 / 코드만·생략 제외 {web_kept_code}줄")
print(f"  Flutter sign_in_page.dart: {flutter_total}줄 / 코드만 {flutter_code}줄")
print()

rows = [
    ("① 단순 비율", flutter_total, web_total,
     "raw↔raw지만 생략분이 분모에 남음 → 과소평가. 진단용"),
    ("② 생략 보정(raw↔raw)", flutter_total, web_kept,
     "예상 **파일 볼륨** — 밴드 상한"),
    ("③ 코드 라인만", flutter_code, web_total_code,
     "code↔code지만 생략분이 분모에 남음 → 과소평가. 진단용"),
    ("④ 코드+생략 보정(code↔code)", flutter_code, web_kept_code,
     "**작업량 proxy** — 밴드 하한"),
]
print("  팽창률")
for label, num, den, note in rows:
    print(f"    {label:<26} {num:>3} / {den:>3} = {num / den:.2f}x   {note}")
print()

print("== 팽창의 정체: 주석 ==")
print()
print(f"  {'':<22}{'raw':>6}{'code':>7}{'comment':>9}{'blank':>7}")
print(f"  {'sign_in_page.dart':<22}{flu['raw']:>6}{flu['code']:>7}"
      f"{flu['comment']:>9}{flu['blank']:>7}")
print(f"  {'웹 두 파일':<20}{web_total:>6}{web_total_code:>7}"
      f"{web_comment:>9}{web_blank:>7}")
print()
print(f"  주석 {flu['comment']}줄 대 {web_comment}줄. 측정된 팽창의 사실상 전부가 한국어 주석이다.")
print("  게다가 이 파일의 주석 밀도는 주석 있는 Dart의 대표값이 아니다 — 참조 화면이라")
print("  복사될 화면이 반복하지 않을 일회성 서술(Phase 0 규약 재진술, mt-[46px] 근거,")
print("  로고 갭 주석)을 담고 있다.")
print()

low, high = rows[3][1] / rows[3][2], rows[1][1] / rows[1][2]
lo_lines, hi_lines = TOTAL_WEB_UI_LINES * low, TOTAL_WEB_UI_LINES * high

print("== 권고: 단일 수치가 아니라 밴드로 기록하라 ==")
print()
print(f"  작업량 proxy (④ code↔code) {low:.2f}x → 약 {round(lo_lines, -2):,.0f}줄")
print(f"  파일 볼륨   (② raw↔raw)   {high:.2f}x → 약 {round(hi_lines, -2):,.0f}줄")
print(f"  ▶ 밴드: 약 {low:.2f}x–{high:.2f}x → {round(lo_lines, -2):,.0f}–{round(hi_lines, -2):,.0f}줄")
print()
print(f"  밴드 폭({round(hi_lines - lo_lines, -2):,.0f}줄 ≈ 주석)은 팀이 고르는 **문서화 예산**이지")
print("  마이그레이션이 유발하는 비용이 아니다. ②로 외삽하면 결과의 약 1/3이 주석이다.")
print()

print("== 참고 데이터포인트: Task 7·8 공통 위젯 3쌍 (평균 내지 말 것) ==")
print()
for web_paths, dart_path, caveat in REFERENCE_PAIRS:
    w = sum(len((web_root / p).read_text(encoding="utf-8").splitlines())
            for p in web_paths)
    d = len((flutter_root / dart_path).read_text(encoding="utf-8").splitlines())
    label = " + ".join(Path(p).name for p in web_paths)
    print(f"  {label} {w}줄 → {Path(dart_path).name} {d}줄 = {d / w:.2f}x")
    print(f"      caveat: {caveat}")
print()
print("  대응이 1:1이 아니라 평균은 의미가 없다. 다만 이 값들이 참조 화면보다 **위쪽**을")
print(f"  가리킨다는 사실은 기록해야 한다 — src/shared(.tsx {SHARED_TSX_LINES:,}줄)가 전체")
print(f"  {TOTAL_WEB_UI_LINES:,}줄의 {SHARED_TSX_LINES / TOTAL_WEB_UI_LINES:.0%}를 차지한다.")
print()

print("== 주의 ==")
print()
print("  - **외삽 방향성(과소평가 쪽):** 생략한 45줄은 네비게이션·SVG 자산·토스트·")
print("    웹뷰 브릿지다 — Flutter에서 가장 크게 팽창할 범주. 그걸 **뺀** 나머지로 잰")
print(f"    비율을 그 범주를 **포함한** {TOTAL_WEB_UI_LINES:,}줄 전체에 적용하므로,")
print("    외삽이 측정 영역 밖으로 나가며 실제보다 낮게 잡힐 가능성이 크다.")
print("  - **표본 n=1**(+참고 3쌍). 리스트·그리드·캘린더(§8 재현 난이도 상위)는 위젯")
print("    트리 중첩이 깊어 더 팽창할 수 있다 → Phase 3~5 착수 시 각 도메인 첫")
print("    화면에서 재측정할 것.")
print("  - 줄 수는 공수에 비례하지 않는다(§2와 동일한 단서). 방향성으로만 쓸 것.")
print("  - 생략 구간은 사람이 원본을 읽고 확정했다. 웹이 바뀌면 이 스크립트가 줄 수")
print("    검사에서 먼저 멈춘다. 참고 3쌍은 가드 없이 매번 새로 센다.")
EOF
