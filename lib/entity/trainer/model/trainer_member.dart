import 'package:flutter/foundation.dart';

/// 웹 `RegisteredStudent`(`feature/manage/model/types.ts:7~18`)
/// = 백엔드 `MemberInTeamResult`(`GET /api/v1/trainers/members`).
///
/// ## 목록이 비면 `[]`가 아니라 `null`이다
///
/// 서비스가 `members.isEmpty() ? null : members`를 돌려준다. 화면은 그
/// **null과 "검색 결과 0건"을 다른 빈 상태로 그린다** — 전자는 `회원
/// 등록하기` 버튼이 있고 후자는 없다. 그래서 [fromListJson]은 빈 리스트로
/// 뭉개지 않고 null을 그대로 흘린다.
///
/// ## `isNonmember`를 담는 이유 — 화면은 이 값을 쓰지 않는데도
///
/// 웹은 `item.nonmember`를 읽는데 서버가 보내는 키는 `isNonmember`다
/// (Java record 컴포넌트명 그대로 Jackson이 직렬화한다). 즉 웹에서 그
/// 조건은 **항상 `undefined`**라 `가입` 배지가 전원에게 붙는다 → BUG-41.
/// 그 동작을 그대로 옮기므로 화면은 이 필드를 보지 않지만, 필드를 지우면
/// "왜 안 보는가"의 근거가 사라진다. 값을 담아 두고 보지 않는 것이
/// 버그를 재현하고 있다는 사실을 코드에 남긴다.
///
/// ## 담지 않는 것
///
/// `userId`·`email`·`courseId` — 이 화면이 읽지 않는다. `courseId`는 웹
/// 타입 선언에조차 없다.
@immutable
class TrainerMember {
  const TrainerMember({
    required this.memberId,
    required this.name,
    required this.ranking,
    required this.lessonCnt,
    required this.remainLessonCnt,
    required this.isNonmember,
    this.nickName,
    this.fileUrl,
  });

  factory TrainerMember.fromJson(Map<String, dynamic> json) => TrainerMember(
    memberId: json['memberId'] as int,
    name: json['name'] as String? ?? '',
    ranking: json['ranking'] as int? ?? 0,
    lessonCnt: json['lessonCnt'] as int? ?? 0,
    remainLessonCnt: json['remainLessonCnt'] as int? ?? 0,
    // 웹은 `nonmember`(없는 키)를 읽지만 여기서는 **서버가 실제로 보내는
    // 키**를 담는다. 배지 조건은 화면에서 웹과 같게 고정한다.
    isNonmember: json['isNonmember'] as bool? ?? false,
    nickName: json['nickName'] as String?,
    fileUrl: json['fileUrl'] as String?,
  );

  /// 응답 `data`를 목록으로. **회원이 없으면 null**(위 설명 참고).
  static List<TrainerMember>? fromListJson(Object? data) {
    if (data is! List) {
      return null;
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(TrainerMember.fromJson)
        .toList();
  }

  final int memberId;
  final String name;

  /// 순위. 실측 응답에서 순위가 없는 회원은 **999**로 온다(0이나 null이
  /// 아니다). 1·2·3위만 프로필 테두리 색이 다르다.
  final int ranking;

  final int lessonCnt;
  final int remainLessonCnt;

  /// **화면이 읽지 않는다** — BUG-41을 그대로 옮기기 때문이다(위 설명).
  final bool isNonmember;

  /// 웹 타입은 `null`로 못박혀 있지만 **서버는 실제 별칭을 보낸다**
  /// (BUG-4). 웹은 `{item.nickName && ...}`로 그리므로 값이 오면 그려진다 —
  /// 타입 거짓말일 뿐 동작 버그는 아니라서 그대로 옮긴다.
  final String? nickName;

  final String? fileUrl;
}
