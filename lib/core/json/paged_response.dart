import 'package:flutter/foundation.dart';

import 'json_number.dart';

/// 백엔드 `CustomPaging` 응답 봉투.
///
/// 컨트롤러들이 `ApiResult<CustomPaging>`을 **raw type**으로 돌려주고 서비스가
/// `content`와 `mainData`를 채운다. 화면마다 `mainData`의 내용만 다르고
/// 나머지는 같다 — 2026-09-18 실측으로 확인했다:
///
/// | 화면 | `mainData` |
/// |---|---|
/// | S3 수강권 (`members/{id}/course`) | `{course, gymName}` |
/// | S4 포인트 (`members/{id}/point`) | `{searchDate, monthPoint, totalPoint}` |
///
/// **두 번째 사용처가 생겨 올렸다**(`asIntOrNull`이 그렇게 만들어진 것과 같다).
/// 회원관리 계열에 페이징 화면이 더 남아 있어(S5·S8·S16·S18) 여기서 한 번
/// 정하는 편이 낫다.
///
/// ## 실측으로 정한 두 가지
///
/// - **와이어 키는 `isLast`다.** Java `boolean isLast`의 빈 게터가 `last`로
///   직렬화되는 흔한 함정에 걸리지 않았다(S3·S4 응답 둘 다 확인).
/// - **빈 목록은 `[]`다.** 웹 타입 선언과 화면 가드는 `null`도 상정하므로
///   양쪽 다 파싱한다.
@immutable
class PagedResponse<T> {
  const PagedResponse({
    required this.content,
    required this.isLast,
    required this.pageNumber,
    required this.mainData,
  });

  /// [item]이 null을 돌려준 원소는 버린다(모르는 모양의 항목).
  static PagedResponse<T> fromJson<T>(
    Object? json, {
    required T? Function(Object?) item,
  }) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final rawContent = map['content'];

    return PagedResponse<T>(
      content: rawContent is List
          ? rawContent.map(item).whereType<T>().toList(growable: false)
          : const [],
      // 값이 없으면 **true**로 본다. false로 두면 다음 페이지를 영원히
      // 조르는 화면이 된다 — 모르는 쪽으로 기울일 때 덜 위험한 값이다.
      isLast: map['isLast'] is bool ? map['isLast'] as bool : true,
      pageNumber: asIntOrNull(map['pageNumber']) ?? 0,
      mainData: map['mainData'],
    );
  }

  final List<T> content;
  final bool isLast;
  final int pageNumber;

  /// 화면별 모델이 해석한다. 여기서 타입을 못 박지 않는 이유는 엔드포인트마다
  /// 내용이 다르고, 봉투가 그것을 알 필요가 없기 때문이다.
  final Object? mainData;
}
