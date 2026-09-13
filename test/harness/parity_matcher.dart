import 'dart:convert';
import 'dart:io';

import 'request_capture.dart';

/// 값을 대조하지 않고 **키 존재만** 확인하는 필드.
///
/// 골든은 실제 계정으로 캡처한 HAR에서 나오고 테스트는 더미 값을 넣으므로
/// 값까지 비교하면 항상 실패한다. 자격증명·개인정보·매 요청 달라지는
/// 토큰류가 여기 해당한다. `har_to_golden.py`는 이 키들의 값을
/// 마스킹해서 저장하므로 골든 파일에 평문이 남지 않는다.
const Set<String> kMaskedKeys = {
  'password',
  'newPassword',
  'email',
  'phoneNumber',
  'accessToken',
  'refreshToken',
  'id_token',
  'code',
  'state',
};

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
  if (golden.path != actual.path) {
    diffs.add('path: 기대 ${golden.path}, 실제 ${actual.path}');
  }

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
  } else {
    final goldenEncoded = _tryEncode(goldenBody);
    final actualEncoded = _tryEncode(actualBody);
    if (goldenEncoded == null || actualEncoded == null) {
      diffs.add(_unsupportedTypeDiff('body', goldenBody, actualBody));
    } else if (goldenEncoded != actualEncoded) {
      diffs.add('body: 기대 $goldenBody, 실제 $actualBody');
    }
  }

  return diffs;
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
      'JSON 직렬화가 불가능한 본문은 아직 비교할 수 없다. '
      'FormData(파일 업로드) 지원은 Phase 7에서 필요하다.';
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
    if (!actual.containsKey(key)) {
      diffs.add('$label.$key: 누락됨');
      continue;
    }
    if (maskedKeys.contains(key)) {
      continue; // 키 존재만 확인하고 값은 대조하지 않는다
    }

    final goldenEncoded = _tryEncode(golden[key]);
    final actualEncoded = _tryEncode(actual[key]);
    if (goldenEncoded == null || actualEncoded == null) {
      diffs.add(_unsupportedTypeDiff('$label.$key', golden[key], actual[key]));
      continue;
    }
    if (goldenEncoded == actualEncoded) {
      continue;
    }
    if (coerceScalarTypes && '${golden[key]}' == '${actual[key]}') {
      continue; // 타입만 다르고 표기가 같다 (예: 골든 '0' vs 실제 0)
    }
    diffs.add('$label.$key: 기대 ${golden[key]}, 실제 ${actual[key]}');
  }
  for (final key in actual.keys) {
    if (!golden.containsKey(key)) {
      diffs.add('$label.$key: 예상치 못한 추가 (실제값 ${actual[key]})');
    }
  }
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
