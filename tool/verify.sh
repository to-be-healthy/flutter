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
