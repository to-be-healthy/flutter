#!/usr/bin/env python3
"""har_to_golden.py 회귀 테스트.

골든에 평문 자격증명이 남지 않도록 강제하는 유일한 장치가 mask()이고,
Dart 쪽 kMaskedKeys 와의 동기화도 사람 눈 말고는 지키는 게 없다.
둘 다 여기서 고정한다.

실행: python3 -m unittest discover -s tool -p '*_test.py'
"""
import contextlib
import io
import json
import os
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import har_to_golden as h  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
DART_MATCHER = REPO_ROOT / 'test' / 'harness' / 'parity_matcher.dart'


def write_har(directory, entries):
    path = Path(directory) / 'sample.har'
    path.write_text(
        json.dumps({'log': {'entries': entries}}), encoding='utf-8'
    )
    return str(path)


def request(method, url, body=None, mime='application/json'):
    req = {'method': method, 'url': url}
    if body is not None:
        req['postData'] = {'mimeType': mime, 'text': body}
    return {'request': req}


class MaskTest(unittest.TestCase):
    def test_민감_키를_최상위에서_마스킹한다(self):
        masked = h.mask({'email': 'real@user.com', 'memberType': 'STUDENT'})
        self.assertEqual(masked, {'email': '***', 'memberType': 'STUDENT'})

    def test_중첩_dict까지_재귀_마스킹한다(self):
        masked = h.mask(
            {'member': {'deeper': {'phoneNumber': '01012345678', 'age': 30}}}
        )
        self.assertEqual(
            masked, {'member': {'deeper': {'phoneNumber': '***', 'age': 30}}}
        )

    def test_list_안의_dict까지_재귀_마스킹한다(self):
        masked = h.mask([{'accessToken': 'at-1', 'id': 7}, {'code': 'c'}])
        self.assertEqual(masked, [{'accessToken': '***', 'id': 7},
                                  {'code': '***'}])

    def test_스칼라와_None은_그대로_둔다(self):
        self.assertIsNone(h.mask(None))
        self.assertEqual(h.mask('scalar'), 'scalar')
        self.assertEqual(h.mask(3), 3)


class ConvertTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def convert(self, entries, api_host=None):
        return h.convert(write_har(self.tmp.name, entries), api_host)

    def test_정적_자원과_비api_요청을_걸러낸다(self):
        out, stats = self.convert([
            request('GET', 'https://web.example.com/_next/static/chunk.js'),
            request('GET', 'https://www.google-analytics.com/collect?v=1'),
            request('GET', 'https://api.example.com/api/v1/members/me'),
        ])
        self.assertEqual([r['path'] for r in out], ['/api/v1/members/me'])
        self.assertEqual(stats['skipped_ext'], 1)
        self.assertEqual(stats['skipped_non_api'], 1)

    def test_host_지정시_다른_호스트를_걸러낸다(self):
        out, stats = self.convert([
            request('GET', 'https://api.example.com/api/v1/a'),
            request('GET', 'https://other.example.com/api/v1/b'),
        ], api_host='api.example.com')
        self.assertEqual([r['path'] for r in out], ['/api/v1/a'])
        self.assertEqual(stats['skipped_host'], 1)

    def test_본문과_쿼리의_민감값을_마스킹하고_메서드를_대문자로_만든다(self):
        out, _ = self.convert([
            request('post', 'https://api.example.com/api/v1/members/login',
                    body=json.dumps({'email': 'real@user.com',
                                     'password': 'hunter2',
                                     'memberType': 'STUDENT'})),
            request('get',
                    'https://api.example.com/api/v1/me?code=authcode&page=0'),
        ])
        self.assertEqual(out[0]['method'], 'POST')
        self.assertEqual(out[0]['body'],
                         {'email': '***', 'password': '***',
                          'memberType': 'STUDENT'})
        self.assertEqual(out[1]['method'], 'GET')
        self.assertEqual(out[1]['query'], {'code': '***', 'page': '0'})

    def test_중복_쿼리키는_리스트로_단일값은_스칼라로_남긴다(self):
        out, _ = self.convert([
            request('GET', 'https://api.example.com/api/v1/a?t=1&t=2&s=x'),
        ])
        self.assertEqual(out[0]['query'], {'t': ['1', '2'], 's': 'x'})

    def test_빈_쿼리값을_보존한다(self):
        # ?keyword= 가 사라지면 검색·필터 화면에서 "예상치 못한 추가" 오탐이 난다.
        out, _ = self.convert([
            request('GET', 'https://api.example.com/api/v1/search?keyword='),
        ])
        self.assertEqual(out[0]['query'], {'keyword': ''})

    def test_JSON이_아닌_본문은_원문으로_보존한다(self):
        out, _ = self.convert([
            request('POST', 'https://api.example.com/api/v1/upload',
                    body='not-json', mime='text/plain'),
        ])
        self.assertEqual(out[0]['body'], 'not-json')

    def test_본문이_없으면_None이다(self):
        out, _ = self.convert([
            request('GET', 'https://api.example.com/api/v1/a'),
        ])
        self.assertIsNone(out[0]['body'])


class EmptyResultTest(unittest.TestCase):
    """빈 골든은 어떤 플로우든 통과시킨다 — 조용히 성공하면 안 된다."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cwd = os.getcwd()
        self.addCleanup(os.chdir, self.cwd)

    def run_main(self, argv):
        os.chdir(self.tmp.name)
        (Path(self.tmp.name) / 'test' / 'fixtures' / 'requests').mkdir(
            parents=True, exist_ok=True
        )
        err = io.StringIO()
        out = io.StringIO()
        old = sys.argv
        sys.argv = argv
        try:
            with contextlib.redirect_stderr(err), contextlib.redirect_stdout(out):
                h.main()
            code = 0
        except SystemExit as e:
            code = e.code or 0
        finally:
            sys.argv = old
        return code, out.getvalue() + err.getvalue()

    def test_전부_걸러지면_비영_종료하고_원인을_말한다(self):
        har = write_har(self.tmp.name, [
            request('GET', 'https://web.example.com/app.js'),
            request('GET', 'https://web.example.com/home'),
        ])
        code, text = self.run_main(['har_to_golden.py', har, 'login'])

        self.assertEqual(code, 1)
        self.assertIn('정적 자원 1건', text)
        self.assertIn('/api/', text)
        self.assertFalse(
            (Path(self.tmp.name) / 'test/fixtures/requests/login.json').exists(),
            '빈 골든 파일을 만들면 안 된다',
        )

    def test_정상_변환은_파일을_쓰고_0으로_끝난다(self):
        har = write_har(self.tmp.name, [
            request('POST', 'https://api.example.com/api/v1/members/login',
                    body=json.dumps({'email': 'a@b.com', 'password': 'pw'})),
        ])
        code, _ = self.run_main(['har_to_golden.py', har, 'login'])

        self.assertEqual(code, 0)
        written = json.loads(
            (Path(self.tmp.name) / 'test/fixtures/requests/login.json')
            .read_text(encoding='utf-8')
        )
        self.assertEqual(written[0]['body'], {'email': '***',
                                              'password': '***'})


class MaskedKeyDriftTest(unittest.TestCase):
    """Dart kMaskedKeys ↔ Python MASKED_KEYS 동기화 가드.

    Dart 에만 키를 추가하고 Python 에 빠뜨리면 골든에 평문 자격증명이
    커밋되는데, 이 테스트가 없으면 아무것도 실패하지 않는다.
    """

    def test_두_집합이_완전히_같다(self):
        source = DART_MATCHER.read_text(encoding='utf-8')
        block = re.search(
            r'const Set<String> kMaskedKeys = \{(.*?)\};', source, re.S
        )
        self.assertIsNotNone(block, 'kMaskedKeys 선언을 찾지 못했다')

        dart_keys = set(re.findall(r"'([^']+)'", block.group(1)))
        self.assertTrue(dart_keys, 'kMaskedKeys 가 비어 있다')
        self.assertEqual(
            dart_keys,
            set(h.MASKED_KEYS),
            'Dart kMaskedKeys 와 Python MASKED_KEYS 가 어긋났다. '
            '한쪽에만 키를 추가하면 골든에 평문이 남거나 비교가 틀어진다.',
        )


if __name__ == '__main__':
    unittest.main()
