#!/usr/bin/env python3
"""Chrome DevTools HAR → 패리티 골든 픽스처 변환.

사용법:
  python3 tool/har_to_golden.py <input.har> <fixture-name> \\
      [--host geonganghaejim.site] [--path-template]

api 호출만 남기고 정적 자원·문서·분석 요청은 걸러낸다.

옵션:
  --host           이 호스트의 요청만 남긴다. '/api/' 경로 필터와 **AND**로
                   걸린다 — 웹앱과 API가 같은 오리진이라 --host 만으로는
                   Next.js 문서·RSC·_next/data 요청이 함께 들어온다.
  --path-template  경로의 숫자 세그먼트를 '{id}' 로 치환한다. 골든이 캡처한
                   계정의 리소스 id에 묶이지 않게 한다.
"""
import json
import re
import sys
from urllib.parse import urlparse, parse_qs

SKIP_EXT = ('.js', '.css', '.png', '.jpg', '.svg', '.woff', '.woff2', '.ico')

# parity_matcher.dart 의 kMaskedKeys 와 반드시 동일하게 유지할 것.
# 골든 파일에 실계정 자격증명이 평문으로 커밋되는 것을 막는다.
MASKED_KEYS = {
    'password', 'newPassword', 'userId', 'email', 'phoneNumber',
    'accessToken', 'refreshToken', 'id_token', 'code', 'state',
}

# request_capture.dart 의 kCapturedHeaders 와 반드시 동일하게 유지할 것.
# 여기 없는 헤더(User-Agent·타임스탬프 등)는 매 실행 달라지므로 버린다.
CAPTURED_HEADERS = {'content-type', 'authorization'}

# request_capture.dart 의 kPresenceOnlyHeaders 와 반드시 동일하게 유지할 것.
# 값이 아니라 존재만 비교하는 헤더 — 골든에는 마스킹해서 저장한다.
PRESENCE_ONLY_HEADERS = {'authorization'}

# parity_matcher.dart 의 kPathIdPlaceholder / kPathIdSegment 와 반드시
# 동일하게 유지할 것. 한쪽만 바꾸면 골든과 비교기의 규칙이 어긋난다.
PATH_ID_PLACEHOLDER = '{id}'
PATH_ID_SEGMENT = re.compile(r'^\d+$')


def mask(value):
    """민감 키의 값을 재귀적으로 마스킹한다."""
    if isinstance(value, dict):
        return {k: '***' if k in MASKED_KEYS else mask(v)
                for k, v in value.items()}
    if isinstance(value, list):
        return [mask(v) for v in value]
    return value


def pick_headers(raw):
    """HAR 헤더 목록에서 allowlist 만 소문자 키로 남긴다.

    `authorization` 은 값이 실토큰이라 마스킹한다 — 존재 여부만 비교 대상이다.
    같은 헤더가 여러 번 오면 **첫 값**을 쓴다(HTTP/2 HAR 에서 드물게 중복).
    """
    picked = {}
    for header in raw or []:
        name = (header.get('name') or '').lower()
        if name not in CAPTURED_HEADERS or name in picked:
            continue
        picked[name] = ('***' if name in PRESENCE_ONLY_HEADERS
                        else header.get('value', ''))
    return picked


def has_id_segment(path):
    """숫자만으로 이루어진 세그먼트가 있는가."""
    return any(PATH_ID_SEGMENT.match(seg) for seg in path.split('/'))


def templatize_path(path):
    """숫자 세그먼트를 자리표시자로 바꾼다.

    숫자만 치환하는 이유는 백엔드 실측이다: 경로 파라미터 64개 중 60개가
    integer(int64)이고 나머지 4개(status·type·notificationCategory)는 문자열
    열거형이라 값까지 대조돼야 한다. `v1`·`me` 처럼 숫자가 아닌 세그먼트는
    그대로 남는다.
    """
    return '/'.join(
        PATH_ID_PLACEHOLDER if PATH_ID_SEGMENT.match(seg) else seg
        for seg in path.split('/')
    )


def convert(har_path, api_host=None, path_template=False):
    """HAR을 골든 항목 리스트로 바꾼다.

    반환값은 `(항목들, 통계)`. 통계는 결과가 비었을 때 "어느 필터가 전부
    걸렀는지" 알려주기 위한 것이다 — 빈 골든은 어떤 플로우든 통과시키므로
    조용히 넘어가면 안 된다.
    """
    with open(har_path, encoding='utf-8') as f:
        har = json.load(f)

    stats = {'total': 0, 'skipped_ext': 0, 'skipped_host': 0,
             'skipped_non_api': 0, 'id_segment_paths': 0}
    out = []
    for entry in har['log']['entries']:
        stats['total'] += 1
        req = entry['request']
        url = urlparse(req['url'])

        if any(url.path.endswith(ext) for ext in SKIP_EXT):
            stats['skipped_ext'] += 1
            continue
        # 두 필터는 AND 다. --host 만으로 거르면 웹앱과 API가 같은 오리진이라
        # Next.js 문서·RSC·_next/data 요청이 전부 "골든 API 요청"이 된다.
        if api_host and url.netloc != api_host:
            stats['skipped_host'] += 1
            continue
        if '/api/' not in url.path:
            stats['skipped_non_api'] += 1
            continue

        body = None
        post = req.get('postData')
        if post and post.get('text'):
            try:
                body = json.loads(post['text'])
            except json.JSONDecodeError:
                body = post['text']

        # keep_blank_values: `?keyword=` 가 사라지면 검색·필터 화면에서
        # "예상치 못한 추가" 오탐이 난다.
        query = {k: v[0] if len(v) == 1 else v
                 for k, v in parse_qs(url.query,
                                      keep_blank_values=True).items()}

        path = url.path
        if has_id_segment(path):
            stats['id_segment_paths'] += 1
        if path_template:
            path = templatize_path(path)

        out.append({
            'method': req['method'].upper(),
            'path': path,
            'query': mask(query),
            'headers': pick_headers(req.get('headers')),
            'body': mask(body),
        })

    stats['kept'] = len(out)
    return out, stats


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    har_path, name = sys.argv[1], sys.argv[2]
    api_host = None
    if '--host' in sys.argv:
        api_host = sys.argv[sys.argv.index('--host') + 1]
    path_template = '--path-template' in sys.argv

    result, stats = convert(har_path, api_host, path_template)
    dest = f'test/fixtures/requests/{name}.json'

    if not result:
        host_filter = f'(--host {api_host})' if api_host else ''
        print(f'변환 결과가 비어 있다 — {dest} 를 만들지 않았다.', file=sys.stderr)
        print(f"  HAR 엔트리 {stats['total']}건 중 제외: "
              f"정적 자원 {stats['skipped_ext']}건, "
              f"호스트 불일치 {host_filter} {stats['skipped_host']}건, "
              f"경로에 '/api/' 없음 {stats['skipped_non_api']}건",
              file=sys.stderr)
        print('  --host 값과 HAR 캡처 범위를 확인하라. '
              '요청 0건짜리 골든은 어떤 플로우든 통과시킨다.', file=sys.stderr)
        sys.exit(1)

    with open(dest, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f'{dest} 생성: {len(result)}건')
    for r in result:
        print(f"  {r['method']} {r['path']}")

    if stats['id_segment_paths'] and not path_template:
        # 침묵하면 골든이 캡처 계정의 id에 묶인 채 커밋되고, 62개 화면
        # 테스트가 그 id를 하드코딩하게 된다.
        print(f"  경고: 숫자 세그먼트를 가진 경로 {stats['id_segment_paths']}건 — "
              f"--path-template 로 '{PATH_ID_PLACEHOLDER}' 치환을 고려하라.",
              file=sys.stderr)


if __name__ == '__main__':
    main()
