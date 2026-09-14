import 'dart:convert';
import 'dart:io';

import 'request_capture.dart';

/// 값을 대조하지 않고 **키 존재만** 확인하는 필드.
///
/// 골든은 실제 계정으로 캡처한 HAR에서 나오고 테스트는 더미 값을 넣으므로
/// 값까지 비교하면 항상 실패한다. 자격증명·개인정보·매 요청 달라지는
/// 토큰류가 여기 해당한다. `har_to_golden.py`는 이 키들의 값을
/// 마스킹해서 저장하므로 골든 파일에 평문이 남지 않는다.
///
/// `userId`는 **로그인 식별자**다(백엔드 `CommandLoginMember.userId` — 웹은
/// 이메일이 아니라 아이디로 로그인한다). 마스킹하지 않으면 골든을 뜰 때 실제
/// 계정 아이디가 평문으로 레포에 커밋되고, 테스트의 더미 아이디와 값이 달라
/// 패리티가 **계약과 무관한 이유로** 실패한다. `password`와 같은 이유로 여기 있다.
const Set<String> kMaskedKeys = {
  'password',
  'newPassword',
  'userId',
  'email',
  'phoneNumber',
  'accessToken',
  'refreshToken',
  'id_token',
  'code',
  'state',
};

/// 골든 경로에서 리소스 id 자리를 대신하는 토큰.
///
/// 62개 화면 대부분이 `/api/v1/.../{memberId}`·`{scheduleId}`·
/// `{lessonId}`를 친다. 골든은 HAR을 뜬 **그 계정의** id를 담으므로
/// 리터럴로 두면 모든 화면 테스트가 그 id를 하드코딩해야 하고 다른 계정으로
/// 픽스처를 다시 뜰 수 없다.
///
/// **`tool/har_to_golden.py`의 `PATH_ID_PLACEHOLDER`와 반드시 같게 유지할 것.**
const String kPathIdPlaceholder = '{id}';

/// 자리표시자로 치환할(=자리표시자와 일치할) 세그먼트의 **형태**.
///
/// 값이 아니라 형태만 맞춘다 — "아무 값이나 통과"로 두면 `/members/{id}`
/// 자리에 `/members/me`를 치는 진짜 버그가 통과한다.
///
/// 숫자만 치환하는 이유는 백엔드 실측이다: `openapi/api-docs.json`의 경로
/// 파라미터 64개 중 60개가 `integer(int64)`이고, 나머지 4개
/// (`status`·`type`·`notificationCategory`)는 문자열 **열거형**이라 값까지
/// 대조돼야 한다. 숫자 전용 규칙이 그 둘을 정확히 갈라놓는다.
///
/// **`tool/har_to_golden.py`의 `PATH_ID_SEGMENT`와 반드시 같은 패턴일 것.**
final RegExp kPathIdSegment = RegExp(r'^\d+$');

/// 두 요청의 차이를 사람이 읽을 수 있는 문자열 목록으로 반환한다.
/// 비어 있으면 일치.
///
/// [maskedKeys]에 든 키는 **존재 여부만** 비교하고 값은 비교하지 않는다.
///
/// 쿼리와 본문은 **일부러 다른 엄격도로** 비교한다:
/// - 쿼리: 값 타입을 정규화한다. 골든은 HAR의 쿼리스트링(`parse_qs`)에서 오므로
///   값이 항상 문자열인데 dio는 `{'page': 0}`처럼 숫자를 보낼 수 있다. 타입까지
///   따지면 페이지네이션이 있는 화면이 전부 오탐한다.
/// - 본문: 타입까지 비교한다. 본문은 JSON이라 골든에도 타입이 보존되므로,
///   `"0"`과 `0`을 같게 보면 진짜 직렬화 타입 버그를 놓친다.
///
/// 이 비대칭은 의도된 것이다. 한쪽에 맞춰 통일하지 말 것.
List<String> diffRequests(
  CapturedRequest golden,
  CapturedRequest actual, {
  Set<String> maskedKeys = kMaskedKeys,
}) {
  final diffs = <String>[];

  if (golden.method != actual.method) {
    diffs.add('method: 기대 ${golden.method}, 실제 ${actual.method}');
  }
  _diffPath(golden.path, actual.path, diffs);

  // 헤더는 allowlist(`kCapturedHeaders`)만 캡처·저장되므로 여기서는 남은
  // 것만 비교한다. `kPresenceOnlyHeaders`(authorization)는 마스킹 키와 같은
  // 규칙 — 존재만 본다. content-type은 값까지 본다.
  _diffMap(
    'headers',
    golden.headers,
    actual.headers,
    diffs,
    kPresenceOnlyHeaders,
    coerceScalarTypes: false,
  );

  _diffMap(
    'query',
    golden.query,
    actual.query,
    diffs,
    maskedKeys,
    coerceScalarTypes: true, // HAR 쿼리는 타입이 소실된다
  );

  final goldenBody = golden.body;
  final actualBody = actual.body;
  if (goldenBody is Map && actualBody is Map) {
    _diffMap(
      'body',
      Map<String, dynamic>.from(goldenBody),
      Map<String, dynamic>.from(actualBody),
      diffs,
      maskedKeys,
      coerceScalarTypes: false, // 본문은 타입까지 비교한다
    );
  } else if (goldenBody is List && actualBody is List) {
    _diffList(
      'body',
      goldenBody,
      actualBody,
      diffs,
      maskedKeys,
      coerceScalarTypes: false,
    );
  } else {
    _diffLeaf('body', goldenBody, actualBody, diffs, coerceScalarTypes: false);
  }

  return diffs;
}

/// 경로를 세그먼트 단위로 비교한다.
///
/// [kPathIdPlaceholder]인 골든 세그먼트는 실제 세그먼트가
/// [kPathIdSegment] **형태**이기만 하면 일치로 본다. 자리표시자가 없는
/// 경로에서는 세그먼트 대조가 곧 리터럴 대조라 동작이 달라지지 않는다.
void _diffPath(String golden, String actual, List<String> diffs) {
  if (golden == actual) {
    return;
  }

  final goldenSegments = golden.split('/');
  final actualSegments = actual.split('/');

  if (goldenSegments.length == actualSegments.length) {
    String? mismatch;
    for (var i = 0; i < goldenSegments.length; i++) {
      final g = goldenSegments[i];
      final a = actualSegments[i];
      if (g == a) {
        continue;
      }
      if (g == kPathIdPlaceholder) {
        if (kPathIdSegment.hasMatch(a)) {
          continue;
        }
        // 자리표시자 자리인데 형태가 다르다 — 가장 흔한 실수라 따로 짚는다.
        mismatch = ' ($kPathIdPlaceholder 자리 [$i]에 id 형태가 아닌 \'$a\'가 왔다)';
        break;
      }
      mismatch = ' (세그먼트 [$i]: \'$g\' vs \'$a\')';
      break;
    }
    if (mismatch == null) {
      return;
    }
    diffs.add('path: 기대 $golden, 실제 $actual$mismatch');
    return;
  }

  diffs.add(
    'path: 기대 $golden, 실제 $actual '
    '(세그먼트 개수 ${goldenSegments.length} vs ${actualSegments.length})',
  );
}

/// `jsonEncode`로 값을 정규화한다. 직렬화할 수 없는 타입이면 `null`.
///
/// `FormData`(멀티파트 업로드) 같은 본문이 여기 해당한다. 예외가 호출부로
/// 튀어나가면 "무엇이 왜 실패했는지" 읽을 수 없으므로 여기서 삼키고,
/// [_unsupportedTypeDiff]가 진단 가능한 차이로 바꿔 보고한다.
String? _tryEncode(Object? value) {
  try {
    return jsonEncode(value);
  } on JsonUnsupportedObjectError {
    return null;
  }
}

/// 비교 자체가 불가능한 타입을 만났을 때의 차이 메시지.
String _unsupportedTypeDiff(String label, Object? golden, Object? actual) {
  return '$label: 패리티 비교 미지원 타입 '
      '(기대 ${golden.runtimeType}, 실제 ${actual.runtimeType}) — '
      'FormData 등 JSON 직렬화가 불가능한 본문은 아직 지원하지 않는다.';
}

/// [coerceScalarTypes]가 참이면 `jsonEncode` 결과가 달라도 `toString()`이 같으면
/// 일치로 본다(쿼리 전용 — 위 [diffRequests] 문서의 비대칭 설명 참고).
void _diffMap(
  String label,
  Map<String, dynamic> golden,
  Map<String, dynamic> actual,
  List<String> diffs,
  Set<String> maskedKeys, {
  required bool coerceScalarTypes,
}) {
  for (final key in golden.keys) {
    final path = '$label.$key';

    if (!actual.containsKey(key)) {
      diffs.add('$path: 누락됨');
      continue;
    }
    if (maskedKeys.contains(key)) {
      continue; // 키 존재만 확인하고 값은 대조하지 않는다
    }

    final goldenValue = golden[key];
    final actualValue = actual[key];

    // 중첩 맵은 같은 규칙으로 재귀한다. har_to_golden.py 의 mask()가 중첩까지
    // 재귀 마스킹하므로 비교도 같은 깊이로 가야 중첩 마스킹 키가 동작한다.
    // 덤으로 중첩 맵이 키 순서에 흔들리지 않는다(웹 JSON.stringify 순서와
    // Dart toJson() 선언 순서가 같을 이유가 없다).
    if (goldenValue is Map && actualValue is Map) {
      _diffMap(
        path,
        Map<String, dynamic>.from(goldenValue),
        Map<String, dynamic>.from(actualValue),
        diffs,
        maskedKeys,
        coerceScalarTypes: coerceScalarTypes,
      );
      continue;
    }

    // 리스트도 같은 규칙으로 재귀한다. Python mask()가 리스트 **안쪽 맵까지**
    // 재귀 마스킹하므로, 리스트를 리프로 보고 jsonEncode로 대조하면 마스킹
    // 키를 품은 객체 리스트에서 '***' vs 실제값이라는 보장된 오탐이 난다.
    if (goldenValue is List && actualValue is List) {
      _diffList(
        path,
        goldenValue,
        actualValue,
        diffs,
        maskedKeys,
        coerceScalarTypes: coerceScalarTypes,
      );
      continue;
    }

    _diffLeaf(
      path,
      goldenValue,
      actualValue,
      diffs,
      coerceScalarTypes: coerceScalarTypes,
    );
  }
  for (final key in actual.keys) {
    if (!golden.containsKey(key)) {
      // 실패 출력은 CI 로그에 남는다. 골든에 없는 토큰·자격증명이 실제 값으로
      // 찍히면 안 되므로 여기서도 마스킹한다.
      final shown = maskedKeys.contains(key) ? '***' : actual[key];
      diffs.add('$label.$key: 예상치 못한 추가 (실제값 $shown)');
    }
  }
}

/// 리스트를 원소 단위로 비교한다.
///
/// 라벨에는 인덱스를 대괄호로 이어 붙인다(`body.items[0].email`) — 어느
/// 원소가 어긋났는지 모르면 항목이 많은 목록 요청에서 진단이 불가능하다.
///
/// 길이가 다르면 원소 비교로 내려가지 않는다. 길이가 어긋난 순간 인덱스가
/// 밀려 이후 전 원소가 차이로 찍히므로, 진짜 원인(길이) 한 줄만 보고한다.
void _diffList(
  String label,
  List<dynamic> golden,
  List<dynamic> actual,
  List<String> diffs,
  Set<String> maskedKeys, {
  required bool coerceScalarTypes,
}) {
  if (golden.length != actual.length) {
    diffs.add('$label: 리스트 길이 불일치 (기대 ${golden.length}, 실제 ${actual.length})');
    return;
  }

  for (var i = 0; i < golden.length; i++) {
    final path = '$label[$i]';
    final goldenValue = golden[i];
    final actualValue = actual[i];

    if (goldenValue is Map && actualValue is Map) {
      _diffMap(
        path,
        Map<String, dynamic>.from(goldenValue),
        Map<String, dynamic>.from(actualValue),
        diffs,
        maskedKeys,
        coerceScalarTypes: coerceScalarTypes,
      );
      continue;
    }
    if (goldenValue is List && actualValue is List) {
      _diffList(
        path,
        goldenValue,
        actualValue,
        diffs,
        maskedKeys,
        coerceScalarTypes: coerceScalarTypes,
      );
      continue;
    }

    _diffLeaf(
      path,
      goldenValue,
      actualValue,
      diffs,
      coerceScalarTypes: coerceScalarTypes,
    );
  }
}

/// 리프 값 하나를 비교한다. `jsonEncode` 대조는 **리프에서만** 한다
/// (중첩 맵·리스트는 [_diffMap]/[_diffList]가 재귀로 내려간다).
///
/// 불일치 메시지에 인코딩 결과와 런타임 타입을 함께 싣는다. `'0'`과 `0`처럼
/// 표기가 같고 타입만 다른 경우 "기대 0, 실제 0"으로는 원인을 읽을 수 없다.
void _diffLeaf(
  String label,
  Object? golden,
  Object? actual,
  List<String> diffs, {
  required bool coerceScalarTypes,
}) {
  final goldenEncoded = _tryEncode(golden);
  final actualEncoded = _tryEncode(actual);
  if (goldenEncoded == null || actualEncoded == null) {
    diffs.add(_unsupportedTypeDiff(label, golden, actual));
    return;
  }
  if (goldenEncoded == actualEncoded) {
    return;
  }
  if (coerceScalarTypes && '$golden' == '$actual') {
    return; // 타입만 다르고 표기가 같다 (예: 골든 '0' vs 실제 0)
  }
  diffs.add(
    '$label: 기대 $goldenEncoded(${golden.runtimeType}), '
    '실제 $actualEncoded(${actual.runtimeType})',
  );
}

/// `test/fixtures/requests/<name>.json` 을 읽어 골든 요청 목록을 반환한다.
List<CapturedRequest> loadGolden(String name) {
  final file = File('test/fixtures/requests/$name.json');
  if (!file.existsSync()) {
    throw StateError(
      '골든 픽스처 없음: ${file.path}\n'
      'tool/har_to_golden.py 로 웹에서 캡처한 HAR을 변환해 생성하라.',
    );
  }
  final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;

  // `headers`가 없는 골든은 **헤더를 비교하지 않는 골든**이다 — 없는 키는
  // 대조되지 않으므로 Authorization을 아예 안 붙이는 화면이 조용히 통과한다.
  // 형식 자체를 거부해 "옛 골든을 그대로 쓰는" 경로를 막는다.
  for (var i = 0; i < decoded.length; i++) {
    final entry = decoded[i] as Map<String, dynamic>;
    if (!entry.containsKey('headers')) {
      throw StateError(
        '골든이 옛 형식이다(headers 없음): ${file.path} [$i]\n'
        'headers 없는 골든은 Authorization·content-type 검증을 통째로 건너뛴다.\n'
        'tool/har_to_golden.py 로 HAR을 다시 변환해 골든을 생성하라.',
      );
    }
  }

  return decoded
      .map((e) => CapturedRequest.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// 캡처된 요청 목록이 골든과 순서까지 일치하는지 검사하고,
/// 다르면 사람이 읽을 수 있는 리포트를 예외로 던진다.
void expectParity(
  String fixtureName,
  List<CapturedRequest> actual, {
  Set<String> maskedKeys = kMaskedKeys,
}) {
  final golden = loadGolden(fixtureName);

  if (golden.isEmpty) {
    throw ParityFailure(
      '골든이 비어 있다: test/fixtures/requests/$fixtureName.json\n'
      '요청 0건짜리 골든은 어떤 플로우든 통과시키므로 검증이 되지 않는다.\n'
      'HAR 캡처 범위와 tool/har_to_golden.py 의 --host·경로 필터를 확인하라.',
    );
  }

  if (golden.length != actual.length) {
    throw ParityFailure(
      '요청 개수 불일치: 기대 ${golden.length}건, 실제 ${actual.length}건\n'
      '기대: ${golden.map((r) => '${r.method} ${r.path}').join(', ')}\n'
      '실제: ${actual.map((r) => '${r.method} ${r.path}').join(', ')}',
    );
  }

  final report = <String>[];
  for (var i = 0; i < golden.length; i++) {
    final diffs = diffRequests(golden[i], actual[i], maskedKeys: maskedKeys);
    if (diffs.isNotEmpty) {
      report.add('[$i] ${golden[i].method} ${golden[i].path}');
      report.addAll(diffs.map((d) => '     $d'));
    }
  }

  if (report.isNotEmpty) {
    throw ParityFailure('API 요청 패리티 불일치:\n${report.join('\n')}');
  }
}

/// `package:flutter_test`의 `TestFailure`와 이름이 겹치지 않도록 분리한다.
class ParityFailure implements Exception {
  ParityFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
