# HAR 원본 보관소

`tool/har_to_golden.py`의 입력이 되는 브라우저 HAR 내보내기를 여기에 둔다.

**이 디렉터리는 gitignore 대상이다** — HAR에는 실계정 토큰·쿠키가 평문으로 들어 있다.

## 지우지 마라

골든 픽스처(`test/fixtures/requests/*.json`)는 HAR에서 스크립트로 생성된다.
생성기나 비교기 규칙이 바뀌면(예: Phase 1의 쿼리스트링 id 자리표시자)
저장된 HAR을 다시 변환하면 끝난다.

HAR을 버리고 골든만 남기면 그 경로가 사라지고, **모든 후속 규칙 변경이
사람의 재캡처**가 된다. 캡처는 브라우저를 열어 실제로 로그인해야 하는 수동 작업이다.

## 변환

```bash
python3 tool/har_to_golden.py har/login.har login \
  --host geonganghaejim.site --path-template
```

변환 직후 확인할 것:
- `test/fixtures/requests/login.json`의 `headers`가 **비어 있지 않은지** (비어 있으면 헤더 검증이 조용히 빈다)
- `userId`·`password`·`authorization` 값이 `***`로 마스킹됐는지
