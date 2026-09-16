import 'package:flutter/foundation.dart';

import '../../../core/json/json_number.dart';

/// 백엔드 `PointDto`. 웹 `StudentPointItem`.
@immutable
class StudentPoint {
  const StudentPoint({
    required this.searchDate,
    required this.monthPoint,
    required this.totalPoint,
  });

  static StudentPoint? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return StudentPoint(
      // 백엔드가 `"YYYY-MM"` 문자열로 준다(`PointDto.searchDate`).
      searchDate: json['searchDate'] as String? ?? '',
      monthPoint: asIntOrNull(json['monthPoint']) ?? 0,
      totalPoint: asIntOrNull(json['totalPoint']) ?? 0,
    );
  }

  final String searchDate;
  final int monthPoint;
  final int totalPoint;

  /// 웹 `searchDate.split('-')[1].split('')[1]` — **버그를 그대로 옮긴 것이다.**
  ///
  /// `"2026-09"` → `"09"` → 두 번째 글자 `"9"`. 01~09월에만 우연히 맞고
  /// **10월은 `"0"`, 11월은 `"1"`, 12월은 `"2"`가 된다.** 웹
  /// `StudentHomePage.tsx:179`·`:314` 두 곳에 같은 식이 중복돼 있다.
  ///
  /// 사용자 결정(2026-09-15): **버그째 이관하고 기록한다.** 이 프로젝트의
  /// 기준은 웹 패리티이고, 여기서 조용히 고치면 대조 기준이 흔들린다.
  /// `deferred-minors.md`에 "웹과 함께 고쳐야 할 것"으로 남겼다.
  ///
  /// `student_home_test.dart`가 10~12월의 잘못된 결과를 **단언으로 고정**한다 —
  /// 나중에 누군가 "개선"으로 조용히 고치면 그 테스트가 먼저 깨져서 이 결정을
  /// 다시 보게 된다.
  String get webMonthLabel {
    final parts = searchDate.split('-');
    if (parts.length < 2 || parts[1].length < 2) {
      // 웹이라면 `undefined`가 되어 "undefined월"로 렌더된다. 앱에서는 빈
      // 문자열로 떨어뜨린다(포맷 실패를 화면에 박지 않는다 —
      // `KoreanDateFormat.reservationHour`와 같은 판단).
      return '';
    }
    return parts[1][1];
  }
}

/// 백엔드 `RankDto`. 웹 `StudentRank`.
@immutable
class StudentRank {
  const StudentRank({
    required this.ranking,
    required this.lastMonthRanking,
    required this.totalMemberCnt,
  });

  static StudentRank? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return StudentRank(
      ranking: asIntOrNull(json['ranking']) ?? 0,
      lastMonthRanking: asIntOrNull(json['lastMonthRanking']) ?? 0,
      totalMemberCnt: asIntOrNull(json['totalMemberCnt']) ?? 0,
    );
  }

  /// 웹 `data?.rank.ranking === 999 ? '-' : ...`.
  ///
  /// **실제 999위가 아니라 "순위 없음" 표식이다.** 숫자로 보고 비교 연산에
  /// 쓰면 화살표 분기가 엉뚱하게 나온다.
  static const int unranked = 999;

  final int ranking;
  final int lastMonthRanking;
  final int totalMemberCnt;

  bool get hasRanking => ranking != unranked;

  /// 웹의 3분기(`==` 없음 / `>` 하락 / 그 외 상승).
  ///
  /// 숫자가 **클수록 낮은 순위**라 `ranking > lastMonthRanking`이 하락이다.
  /// 부등호를 뒤집으면 화살표가 정반대가 된다.
  RankTrend get trend {
    if (ranking == lastMonthRanking) {
      return RankTrend.flat;
    }
    return ranking > lastMonthRanking ? RankTrend.down : RankTrend.up;
  }
}

enum RankTrend { flat, up, down }
