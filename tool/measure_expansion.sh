#!/usr/bin/env bash
# 웹 원본 대비 Flutter 구현의 줄 수 팽창률을 측정한다.
#
# 단순 `wc -l` 비율 하나만 내면 두 가지 편향이 서로 반대 방향으로 섞여
# 어느 쪽으로 얼마나 틀렸는지 알 수 없다:
#   (1) 웹 원본에는 Flutter가 **의도적으로 생략한** 기능(로고·회원가입 버튼·
#       찾기 링크·라우팅·웹뷰 브리지)이 들어 있다 → 분모가 커져 팽창률을 **과소**평가.
#   (2) Flutter 쪽은 Task 7·8이 세운 "토큰 예외는 코드에 이유를 남긴다" 규율
#       때문에 주석이 두껍다 → 분자가 커져 팽창률을 **과대**평가.
# 그래서 4개 기준을 모두 출력한다. 역산에는 웹 §2의 raw 줄 수와 단위가 맞는
# ②(raw↔raw + 생략 보정)를 쓰고, ④(code↔code)는 '주석을 걷어낸 코드 밀도'를
# 읽는 용도다. ①·③은 분모에 생략분이 남은 진단용 값이라 역산에 쓰지 않는다.
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

# 웹 전체 UI 줄 수(MOBILE_MIGRATION_ANALYSIS.md §2 실측).
TOTAL_WEB_UI_LINES = 22257


def is_code(line: str) -> bool:
    """빈 줄·주석 전용 줄을 제외한다. TS/Dart 양쪽에 같은 규칙을 적용한다."""
    s = line.strip()
    if not s:
        return False
    return not (s.startswith("//") or s.startswith("/*") or s.startswith("*"))


web_total = 0
web_kept = 0        # 생략분을 뺀 웹 줄 수
web_kept_code = 0   # 생략분을 빼고 주석·빈 줄까지 뺀 웹 줄 수
web_total_code = 0
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

    web_total += len(lines)
    web_total_code += sum(1 for line in lines if is_code(line))
    kept = [line for i, line in enumerate(lines) if i not in omitted_idx]
    web_kept += len(kept)
    web_kept_code += sum(1 for line in kept if is_code(line))
    detail.append((spec["path"].name, len(lines), len(omitted_idx), spec["omitted"]))

flutter_lines = FLUTTER_FILE.read_text(encoding="utf-8").splitlines()
flutter_total = len(flutter_lines)
flutter_code = sum(1 for line in flutter_lines if is_code(line))

print("웹 원본 (SignInPage + SignInForm)")
for name, total, omitted, ranges in detail:
    print(f"  {name}: {total}줄 (생략 대응 {omitted}줄)")
    for (start, end), reason in ranges:
        span = f"L{start}" if start == end else f"L{start}-{end}"
        print(f"      {span:<10} {reason}")
print(f"  합계: {web_total}줄 / 생략 제외 {web_kept}줄 / 코드만·생략 제외 {web_kept_code}줄")
print()
print(f"Flutter (sign_in_page.dart): {flutter_total}줄 / 코드만 {flutter_code}줄")
print()

rows = [
    ("① 단순 비율", flutter_total, web_total,
     "raw↔raw지만 생략분이 분모에 남음 → 과소평가. 진단용"),
    ("② 생략 보정(raw)", flutter_total, web_kept,
     "raw↔raw + 생략 보정 — **역산 기준**"),
    ("③ 코드 라인만", flutter_code, web_total_code,
     "code↔code지만 생략분이 분모에 남음 → 과소평가. 진단용"),
    ("④ 코드+생략 보정", flutter_code, web_kept_code,
     "code↔code + 생략 보정 — **코드 밀도 기준**"),
]

print("팽창률")
for label, num, den, note in rows:
    print(f"  {label:<18} {num:>3} / {den:>3} = {num / den:.2f}x   {note}")
print()

raw_ratio = rows[1][1] / rows[1][2]
code_ratio = rows[3][1] / rows[3][2]

print(f"전체 UI {TOTAL_WEB_UI_LINES:,}줄 기준 역산:")
print(f"  ② {raw_ratio:.2f}x → 약 {int(TOTAL_WEB_UI_LINES * raw_ratio):,}줄 "
      "(주석 포함 Dart 파일 총량)")
print(f"  ④ {code_ratio:.2f}x → 약 {int(TOTAL_WEB_UI_LINES * code_ratio):,}줄 "
      "(주석 제외 순수 코드)")
print()
print("읽는 법")
print(f"  §2의 {TOTAL_WEB_UI_LINES:,}줄은 주석·빈 줄을 포함한 raw 값이므로, 파일 총량을")
print("  역산할 기준은 같은 raw끼리 비교한 ②다. ①·③은 분모에 생략분이 남아")
print("  과소평가된 진단용 값이지 역산에 쓰지 않는다.")
print(f"  ②({raw_ratio:.2f}x)와 ④({code_ratio:.2f}x)의 차이는 Flutter가 더 복잡해서가 아니라")
print("  **주석 때문이다** — 코드 밀도 자체는 웹과 거의 같다(④). Task 7·8이 세운")
print("  \"토큰 예외는 이유를 코드에 남긴다\" 규율의 비용이 그 차이만큼이고,")
print("  Phase 1~8이 같은 규율을 유지한다는 전제에서 ②가 맞는 역산 기준이다.")
print()
print("주의")
print("  - 이 수치는 **폼 화면 1개** 기준이다. 리스트·그리드·캘린더가 많은")
print("    도메인은 위젯 트리 중첩이 깊어 팽창률이 더 클 수 있다.")
print("    Phase 3~5 착수 시 각 도메인 첫 화면에서 재측정할 것.")
print("  - 줄 수는 공수에 비례하지 않는다(§2와 동일한 단서). 방향성으로만 쓸 것.")
print("  - 생략 구간은 사람이 원본을 읽고 확정했다. 웹이 바뀌면 이 스크립트가")
print("    줄 수 검사에서 먼저 멈춘다.")
EOF
