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
DART_CAPTURE = REPO_ROOT / 'test' / 'harness' / 'request_capture.dart'


def dart_set(source, name):
    """Dart 의 `const Set<String> <name> = {...}` 에서 문자열 리터럴을 뽑는다."""
    block = re.search(
        r'const Set<String> %s = \{(.*?)\};' % name, source, re.S
    )
    assert block, f'{name} 선언을 찾지 못했다'
    return set(re.findall(r"'([^']+)'", block.group(1)))


def write_har(directory, entries):
    path = Path(directory) / 'sample.har'
    path.write_text(
        json.dumps({'log': {'entries': entries}}), encoding='utf-8'
    )
    return str(path)


def request(method, url, body=None, mime='application/json', headers=None):
    req = {'method': method, 'url': url}
    if body is not None:
        req['postData'] = {'mimeType': mime, 'text': body}
    if headers is not None:
        req['headers'] = [{'name': n, 'value': v} for n, v in headers]
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


class HeaderTest(unittest.TestCase):
    """allowlist 헤더만, 소문자 키로, authorization 은 마스킹해서 남긴다."""

    def test_allowlist만_남기고_키를_소문자로_만든다(self):
        picked = h.pick_headers([
            {'name': 'Content-Type', 'value': 'application/json;charset=UTF-8'},
            {'name': 'User-Agent', 'value': 'Mozilla/5.0'},
            {'name': 'Accept-Encoding', 'value': 'gzip'},
        ])
        self.assertEqual(
            picked, {'content-type': 'application/json;charset=UTF-8'}
        )

    def test_authorization은_값을_마스킹하고_존재만_남긴다(self):
        # 골든에 실토큰이 평문으로 커밋되면 안 된다.
        picked = h.pick_headers([
            {'name': 'authorization', 'value': 'Bearer eyJreal.token'},
        ])
        self.assertEqual(picked, {'authorization': '***'})

    def test_같은_헤더가_여러번_오면_첫_값을_쓴다(self):
        picked = h.pick_headers([
            {'name': 'Content-Type', 'value': 'first'},
            {'name': 'content-type', 'value': 'second'},
        ])
        self.assertEqual(picked, {'content-type': 'first'})

    def test_헤더가_없으면_빈_맵이다(self):
        self.assertEqual(h.pick_headers(None), {})

    def test_변환_결과에_headers_키가_항상_있다(self):
        # Dart loadGolden 이 headers 없는 골든을 거부한다.
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        out, _ = h.convert(write_har(tmp.name, [
            request('GET', 'https://api.example.com/api/v1/a'),
            request('POST', 'https://api.example.com/api/v1/b',
                    body='{}', headers=[('Authorization', 'Bearer t'),
                                        ('Content-Type', 'application/json')]),
        ]))
        self.assertEqual([r['headers'] for r in out],
                         [{}, {'authorization': '***',
                               'content-type': 'application/json'}])


class PathTemplateTest(unittest.TestCase):
    """숫자 세그먼트만 자리표시자로 바꾼다 (열거형은 리터럴로 남긴다)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def convert(self, entries, **kw):
        return h.convert(write_har(self.tmp.name, entries), **kw)

    def test_숫자_세그먼트를_자리표시자로_바꾼다(self):
        out, _ = self.convert([
            request('GET', 'https://api.example.com/api/v1/members/17/memo'),
        ], path_template=True)
        self.assertEqual(out[0]['path'], '/api/v1/members/{id}/memo')

    def test_자리표시자가_여러개여도_각각_바꾼다(self):
        out, _ = self.convert([
            request('GET', 'https://api.example.com/api/v1/schedule/40/7'),
        ], path_template=True)
        self.assertEqual(out[0]['path'], '/api/v1/schedule/{id}/{id}')

    def test_문자열_열거형_세그먼트는_그대로_둔다(self):
        # OpenAPI 실측: status·type·notificationCategory 는 값까지 대조돼야 한다.
        out, _ = self.convert([
            request('GET',
                    'https://api.example.com/api/v1/schedule/trainer/COMPLETED'),
        ], path_template=True)
        self.assertEqual(out[0]['path'], '/api/v1/schedule/trainer/COMPLETED')

    def test_v1_처럼_숫자가_섞인_세그먼트는_그대로_둔다(self):
        out, _ = self.convert([
            request('GET', 'https://api.example.com/api/v1/members/me'),
        ], path_template=True)
        self.assertEqual(out[0]['path'], '/api/v1/members/me')

    def test_기본값은_치환하지_않는다(self):
        out, _ = self.convert([
            request('GET', 'https://api.example.com/api/v1/members/17/memo'),
        ])
        self.assertEqual(out[0]['path'], '/api/v1/members/17/memo')

    def test_치환하지_않았는데_숫자_세그먼트가_있으면_통계에_남는다(self):
        out, stats = self.convert([
            request('GET', 'https://api.example.com/api/v1/members/17/memo'),
            request('GET', 'https://api.example.com/api/v1/members/me'),
        ])
        self.assertEqual(stats['id_segment_paths'], 1)


class HostAndApiFilterTest(unittest.TestCase):
    """--host 와 '/api/' 필터는 AND 다 (OR 면 웹 문서 요청이 골든에 들어온다)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_같은_오리진의_next_문서_요청을_걸러낸다(self):
        # 웹앱과 API가 같은 오리진이라 현실적 호출은 --host geonganghaejim.site 다.
        out, stats = h.convert(write_har(self.tmp.name, [
            request('GET', 'https://geonganghaejim.site/sign-in'),
            request('GET',
                    'https://geonganghaejim.site/_next/data/abc/home.json'),
            request('GET', 'https://geonganghaejim.site/api/v1/members/me'),
        ]), api_host='geonganghaejim.site')

        self.assertEqual([r['path'] for r in out], ['/api/v1/members/me'])
        self.assertEqual(stats['skipped_non_api'], 2)


class HeaderKeyDriftTest(unittest.TestCase):
    """Dart request_capture.dart ↔ Python 헤더 allowlist 동기화 가드."""

    def test_캡처_헤더_집합이_같다(self):
        source = DART_CAPTURE.read_text(encoding='utf-8')
        self.assertEqual(
            dart_set(source, 'kCapturedHeaders'),
            set(h.CAPTURED_HEADERS),
            'Dart kCapturedHeaders 와 Python CAPTURED_HEADERS 가 어긋났다.',
        )

    def test_존재만_비교하는_헤더_집합이_같다(self):
        source = DART_CAPTURE.read_text(encoding='utf-8')
        self.assertEqual(
            dart_set(source, 'kPresenceOnlyHeaders'),
            set(h.PRESENCE_ONLY_HEADERS),
            'Dart kPresenceOnlyHeaders 와 Python PRESENCE_ONLY_HEADERS 가 어긋났다.',
        )


class PathTemplateDriftTest(unittest.TestCase):
    """생성기와 비교기가 같은 자리표시자 규칙을 쓰는지 고정한다.

    한쪽만 바꾸면 골든은 `{id}` 를 담는데 비교기는 리터럴로 대조해 모든
    화면이 실패하거나, 반대로 비교가 헐거워진다.
    """

    def test_자리표시자_토큰이_같다(self):
        source = DART_MATCHER.read_text(encoding='utf-8')
        token = re.search(
            r"const String kPathIdPlaceholder = '([^']+)';", source
        )
        self.assertIsNotNone(token, 'kPathIdPlaceholder 선언을 찾지 못했다')
        self.assertEqual(token.group(1), h.PATH_ID_PLACEHOLDER)

    def test_세그먼트_패턴이_같다(self):
        source = DART_MATCHER.read_text(encoding='utf-8')
        pattern = re.search(
            r"final RegExp kPathIdSegment = RegExp\(r'([^']+)'\);", source
        )
        self.assertIsNotNone(pattern, 'kPathIdSegment 선언을 찾지 못했다')
        self.assertEqual(pattern.group(1), h.PATH_ID_SEGMENT.pattern)


if __name__ == '__main__':
    unittest.main()
