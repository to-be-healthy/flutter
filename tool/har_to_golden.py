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
    'password', 'newPassword', 'email', 'phoneNumber',
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
    with open(har_path, encoding='utf-8') as f:
        har = json.load(f)

    out = []
    for entry in har['log']['entries']:
        req = entry['request']
        url = urlparse(req['url'])

        if any(url.path.endswith(ext) for ext in SKIP_EXT):
            continue
        if api_host and url.netloc != api_host:
            continue
        if not api_host and '/api/' not in url.path:
            continue

        body = None
        post = req.get('postData')
        if post and post.get('text'):
            try:
                body = json.loads(post['text'])
            except json.JSONDecodeError:
                body = post['text']

        query = {k: v[0] if len(v) == 1 else v
                 for k, v in parse_qs(url.query).items()}

        out.append({
            'method': req['method'].upper(),
            'path': url.path,
            'query': mask(query),
            'body': mask(body),
        })

    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    har_path, name = sys.argv[1], sys.argv[2]
    api_host = None
    if '--host' in sys.argv:
        api_host = sys.argv[sys.argv.index('--host') + 1]

    result = convert(har_path, api_host)
    dest = f'test/fixtures/requests/{name}.json'
    with open(dest, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f'{dest} 생성: {len(result)}건')
    for r in result:
        print(f"  {r['method']} {r['path']}")


if __name__ == '__main__':
    main()
