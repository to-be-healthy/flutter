#!/usr/bin/env bash
# Phase 0 검증 루프 1: 구조적 파손 검출
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== dart format =="
dart format --set-exit-if-changed lib test

echo "== flutter analyze =="
# --no-fatal-infos 를 붙이지 않는다. Flutter analyze 의 fatal-infos 기본값은
# true 이고, 그 플래그는 analysis_options.yaml 에 설정한 린트
# (prefer_const_constructors·prefer_final_locals·always_declare_return_types·
# avoid_print·flutter_lints 전체)의 심각도를 통째로 무력화한다 — 린트가
# 장식품이 된다. 62개 화면이 붙은 뒤에는 되돌리는 비용이 커진다.
flutter analyze

echo "== har_to_golden.py 테스트 =="
python3 -m unittest discover -s tool -p '*_test.py'

echo "== flutter test =="
flutter test --reporter compact

echo "OK: 모든 검증 통과"
