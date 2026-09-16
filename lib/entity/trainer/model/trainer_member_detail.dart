import 'package:flutter/foundation.dart';

import '../../../core/json/json_number.dart';
import '../../course/model/course.dart';
import '../../diet/model/diet.dart';
import '../../point/model/student_point.dart';

/// 웹 `StudentDetail`(`feature/manage/model/types.ts:51~65`)
/// = 백엔드 `MemberDetailResult`(`GET /api/v1/trainers/members/{memberId}`).
///
/// ## 학생 홈과 **같은 중첩 DTO**를 쓴다
///
/// `course`·`point`·`rank`·`diet`는 백엔드 `CourseDto`·`PointDto`·`RankDto`·
/// `DietDto` 그대로라, 학생 홈에서 만든 모델을 그대로 재사용한다. 그래서
/// 이 네 타입이 `entity/home/model/student_home.dart`에서 각자의 엔트리로
/// 올라왔다 — 두 번째 사용처가 생겼을 때 승격하는 이 프로젝트의 규칙이다.
///
/// ## `gym`은 `GymDto`다 — `gymId`가 아니라 `id`
///
/// 웹 타입은 `Gym {gymId, name}`이라고 선언하지만 이 엔드포인트가 주는 것은
/// `GymDto {id, name}`다(BUG-43). 웹은 `.name`만 써서 살아남았다. 화면도
/// 이름만 쓰므로 [gymName]만 담는다 — `MemberInfo`·`TrainerInfo`와 같은
/// 판단이고, 그 배경은 `test/entity/gym/gym_test.dart`에 있다.
///
/// ## 담지 않는 것
///
/// `memberId`(라우트에서 온다) · `memo`(S6이 쓴다) · `lessonDt` ·
/// `lessonStartTime` · `isNonmember` — **S2 화면이 읽지 않는다.**
/// 필요해지는 화면에서 그때 넓힌다.
@immutable
class TrainerMemberDetail {
  const TrainerMemberDetail({
    required this.name,
    required this.ranking,
    required this.gymName,
    required this.rank,
    this.nickName,
    this.fileUrl,
    this.course,
    this.point,
    this.diet,
  });

  static TrainerMemberDetail? fromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final gym = data['gym'];
    return TrainerMemberDetail(
      name: data['name'] as String? ?? '',
      ranking: asIntOrNull(data['ranking']) ?? StudentRank.unranked,
      gymName: gym is Map<String, dynamic> ? gym['name'] as String? ?? '' : '',
      // 웹은 `memberInfo?.rank.ranking`을 **옵셔널 체이닝 없이** 읽는다
      // (`index.tsx:262`). 서버가 빠뜨리면 거기서 터진다 — 여기서는 빈
      // 랭킹으로 흡수한다.
      rank:
          StudentRank.fromJsonOrNull(data['rank']) ??
          const StudentRank(
            ranking: StudentRank.unranked,
            lastMonthRanking: StudentRank.unranked,
            totalMemberCnt: 0,
          ),
      nickName: data['nickName'] as String?,
      fileUrl: data['fileUrl'] as String?,
      course: Course.fromJsonOrNull(data['course']),
      point: StudentPoint.fromJsonOrNull(data['point']),
      diet: HomeDiet.fromJsonOrNull(data['diet']),
    );
  }

  final String name;

  /// 프로필 테두리 색과 `랭킹 N` 줄을 가른다. **999는 "순위 없음"**이다.
  ///
  /// [rank]의 `ranking`과 **다른 필드다.** 이쪽은 `MemberDetailResult`의
  /// 평평한 `ranking`이고, 저쪽은 중첩 `RankDto`의 것이다. 웹도 둘을 따로
  /// 읽는다 — 프로필 줄은 `memberInfo.ranking`, 포인트 카드는
  /// `memberInfo.rank.ranking`이다. 서버가 둘을 같게 채우는지는 확인하지
  /// 않았으므로 합치지 않는다.
  final int ranking;

  final String gymName;
  final StudentRank rank;
  final String? nickName;
  final String? fileUrl;
  final Course? course;
  final StudentPoint? point;

  /// **웹은 이것을 non-null로 보고 `memberInfo.diet.dietId`를 그냥 읽는다.**
  /// 서버가 `diet`를 빠뜨리면 웹은 TypeError로 화면이 통째로 죽는다.
  /// 여기서는 null을 그대로 들고, 화면이 **식단 카드를 아예 안 그리는
  /// 것으로** 흡수한다(죽는 것을 재현하지는 않는다 — 명시적 이탈).
  final HomeDiet? diet;

  /// 웹 `{memberInfo.diet.dietId && ...}` — 오늘 식단 카드.
  bool get hasTodayDiet => (diet?.dietId ?? 0) != 0;

  /// 웹 `{memberInfo.diet.dietId === null && ...}` — 등록 식단 카드.
  ///
  /// **[hasTodayDiet]의 반대가 아니다.** `dietId`가 `0`이면 둘 다 거짓이라
  /// 식단 자리가 통째로 빈다. 웹의 `&&`와 `=== null`을 각각 옮긴 결과다.
  bool get hasNoDietYet => diet != null && diet!.dietId == null;

  /// 웹 `{memberInfo.ranking !== 999 && ...}`.
  bool get showsRanking => ranking != StudentRank.unranked;

  /// 웹 `{memberInfo.ranking !== 999 && memberInfo.nickName && ...}` —
  /// **둘 다** 참일 때만 구분선이 나온다.
  bool get showsDivider =>
      showsRanking && nickName != null && nickName!.isNotEmpty;
}
