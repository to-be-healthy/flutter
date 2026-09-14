## Task 1: 프로젝트 생성 + 검증 파이프라인

**Files:**
- Create: `flutter/pubspec.yaml`, `flutter/lib/main.dart`, `flutter/analysis_options.yaml`
- Create: `flutter/tool/verify.sh`
- Modify: `flutter/README.md`

**Interfaces:**
- Consumes: 없음 (최초 태스크)
- Produces: `tool/verify.sh` — 이후 모든 태스크가 커밋 전 실행하는 검증 스크립트

- [ ] **Step 1: Flutter 프로젝트 생성**

기존 빈 레포 위에 생성한다. `README.md`를 덮어쓰지 않도록 주의.

```bash
cd /Users/seonwoo_jung/workspace/personal/tobehealthy/flutter
flutter create --org com.geonganghaejim --project-name geonganghaejim \
  --platforms android,ios --overwrite .
```

생성 후 번들 ID를 확인한다 — `com.geonganghaejim.geonganghaejim`처럼 잘못 붙었으면 수정한다:

```bash
grep -rn "applicationId\|namespace" android/app/build.gradle.kts
grep -n "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | head -2
```

두 값 모두 정확히 `com.geonganghaejim.app` 이어야 한다. 다르면 해당 파일에서 직접 치환한다.

- [ ] **Step 2: analysis_options.yaml 강화**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    - always_declare_return_types
    - prefer_const_constructors
    - prefer_final_locals
    - avoid_print
```

- [ ] **Step 3: 검증 스크립트 작성**

`tool/verify.sh`:

```bash
#!/usr/bin/env bash
# Phase 0 검증 루프 1: 구조적 파손 검출
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== dart format =="
dart format --set-exit-if-changed lib test

echo "== flutter analyze =="
flutter analyze --no-fatal-infos

echo "== flutter test =="
flutter test --reporter compact

echo "OK: 모든 검증 통과"
```

```bash
chmod +x tool/verify.sh
```

- [ ] **Step 4: 검증 스크립트가 실제로 실패를 잡는지 확인**

일부러 포맷을 깨뜨려 스크립트가 실패하는지 본다. **"에러 없음"은 성공의 증거가 아니다 — 실패를 잡는지 먼저 확인한다.**

```bash
printf '\n\nvoid   badlyFormatted(  ) {}\n' >> lib/main.dart
./tool/verify.sh; echo "exit=$?"
```

Expected: `dart format` 단계에서 **비영(non-zero) 종료**. exit=1 확인.

되돌린다 (`git checkout`을 쓰지 말고 추가한 줄만 제거):

```bash
python3 - << 'EOF'
p = 'lib/main.dart'
s = open(p).read()
s = s.replace('\n\nvoid   badlyFormatted(  ) {}\n', '')
open(p, 'w').write(s)
EOF
./tool/verify.sh; echo "exit=$?"
```

Expected: exit=0

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "chore: Flutter 프로젝트 초기 셋업 및 검증 스크립트 추가"
```

---

