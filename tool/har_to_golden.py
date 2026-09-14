#!/usr/bin/env python3
"""Chrome DevTools HAR → 패리티 골든 픽스처 변환.

사용법:
  python3 tool/har_to_golden.py <input.har> <fixture-name> [--host api.example.com]

api 호출만 남기고 정적 자원·분석 요청은 걸러낸다.
"""
import json
import sys
from urllib.parse import urlparse, parse_qs

SKIP_EXT = ('.js', '.css', '.png', '.jpg', '.svg', '.woff', '.woff2', '.ico')

# parity_matcher.dart 의 kMaskedKeys 와 반드시 동일하게 유지할 것.
# 골든 파일에 실계정 자격증명이 평문으로 커밋되는 것을 막는다.
MASKED_KEYS = {
    'password', 'newPassword', 'userId', 'email', 'phoneNumber',
    'accessToken', 'refreshToken', 'id_token', 'code', 'state',
}


def mask(value):
    """민감 키의 값을 재귀적으로 마스킹한다."""
    if isinstance(value, dict):
        return {k: '***' if k in MASKED_KEYS else mask(v)
                for k, v in value.items()}
    if isinstance(value, list):
        return [mask(v) for v in value]
    return value


def convert(har_path, api_host=None):
    """HAR을 골든 항목 리스트로 바꾼다.

    반환값은 `(항목들, 통계)`. 통계는 결과가 비었을 때 "어느 필터가 전부
    걸렀는지" 알려주기 위한 것이다 — 빈 골든은 어떤 플로우든 통과시키므로
    조용히 넘어가면 안 된다.
    """
    with open(har_path, encoding='utf-8') as f:
        har = json.load(f)

    stats = {'total': 0, 'skipped_ext': 0, 'skipped_host': 0,
             'skipped_non_api': 0}
    out = []
    for entry in har['log']['entries']:
        stats['total'] += 1
        req = entry['request']
        url = urlparse(req['url'])

        if any(url.path.endswith(ext) for ext in SKIP_EXT):
            stats['skipped_ext'] += 1
            continue
        if api_host and url.netloc != api_host:
            stats['skipped_host'] += 1
            continue
        if not api_host and '/api/' not in url.path:
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

        out.append({
            'method': req['method'].upper(),
            'path': url.path,
            'query': mask(query),
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

    result, stats = convert(har_path, api_host)
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


if __name__ == '__main__':
    main()
