import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/entity/point/model/student_point.dart';
import 'package:geonganghaejim/entity/trainer/model/trainer_member_detail.dart';

/// 서버 응답 모양의 최소 골격. 개별 테스트가 필요한 키만 덮어쓴다.
Map<String, dynamic> _json({
  Object? nickName,
  Object? ranking = 999,
  Object? diet = _absent,
  Object? rank = _absent,
  Object? gym = _absent,
  Object? course,
  Object? point,
  Object? fileUrl,
}) {
  final map = <String, dynamic>{
    'memberId': 6,
    'name': '차은우',
    'nickName': nickName,
    'fileUrl': fileUrl,
    'memo': null,
    'ranking': ranking,
    'lessonDt': null,
    'lessonStartTime': null,
    'course': course,
    'point': point,
    'isNonmember': false,
  };
  map['gym'] = gym == _absent
      ? <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'}
      : gym;
  map['rank'] = rank == _absent
      ? <String, dynamic>{
          'ranking': 999,
          'lastMonthRanking': 999,
          'totalMemberCnt': 2,
        }
      : rank;
  map['diet'] = diet == _absent ? _dietJson(dietId: null) : diet;
  return map;
}

const Object _absent = Object();

Map<String, dynamic> _dietJson({required Object? dietId}) => <String, dynamic>{
  'dietId': dietId,
  'breakfast': <String, dynamic>{'fast': false, 'dietFile': null},
  'lunch': <String, dynamic>{'fast': false, 'dietFile': null},
  'dinner': <String, dynamic>{'fast': false, 'dietFile': null},
};

void main() {
  group('TrainerMemberDetail', () {
    test('data가 Map이 아니면 null이다', () {
      expect(TrainerMemberDetail.fromJson(null), isNull);
      expect(TrainerMemberDetail.fromJson('nope'), isNull);
      expect(TrainerMemberDetail.fromJson(<Object>[]), isNull);
    });

    test('gym은 GymDto라 id 필드명이 `id`다 — 이름만 읽는다', () {
      // 웹 타입은 `{gymId, name}`이라고 선언하지만 실제로 오는 것은
      // `GymDto {id, name}`다(BUG-43). `gymId`로 읽으면 항상 비어 있다.
      final detail = TrainerMemberDetail.fromJson(_json())!;

      expect(detail.gymName, '건강해짐 홍대점');
    });

    test('gym이 없어도 죽지 않는다', () {
      final detail = TrainerMemberDetail.fromJson(_json(gym: null))!;

      expect(detail.gymName, '');
    });

    test('rank가 없으면 순위 없음으로 흡수한다', () {
      // 웹은 `memberInfo?.rank.ranking`을 옵셔널 체이닝 없이 읽어 터진다.
      final detail = TrainerMemberDetail.fromJson(_json(rank: null))!;

      expect(detail.rank.ranking, StudentRank.unranked);
      expect(detail.rank.totalMemberCnt, 0);
    });

    group('랭킹 줄 — 웹 `ranking !== 999`', () {
      test('999면 숨긴다', () {
        final detail = TrainerMemberDetail.fromJson(_json(ranking: 999))!;

        expect(detail.showsRanking, isFalse);
      });

      test('999가 아니면 보인다', () {
        final detail = TrainerMemberDetail.fromJson(_json(ranking: 3))!;

        expect(detail.showsRanking, isTrue);
      });

      test('ranking 키가 없으면 순위 없음으로 본다', () {
        final detail = TrainerMemberDetail.fromJson(_json(ranking: null))!;

        expect(detail.ranking, StudentRank.unranked);
        expect(detail.showsRanking, isFalse);
      });
    });

    group('구분선 — 웹 `ranking !== 999 && nickName`', () {
      // **둘 다** 참일 때만 나온다. `||`가 아니다. 네 경우를 전부 고정한다 —
      // 실측 계정은 두 회원 다 `ranking: 999`·`nickName: null`이라
      // 브라우저에서는 한 칸도 볼 수 없었다.
      test('랭킹 있고 별칭 있음 → 보인다', () {
        final detail = TrainerMemberDetail.fromJson(
          _json(ranking: 3, nickName: '은우님'),
        )!;

        expect(detail.showsDivider, isTrue);
      });

      test('랭킹 있고 별칭 없음 → 숨긴다', () {
        final detail = TrainerMemberDetail.fromJson(_json(ranking: 3))!;

        expect(detail.showsRanking, isTrue);
        expect(detail.showsDivider, isFalse);
      });

      test('랭킹 없고 별칭 있음 → 숨긴다', () {
        final detail = TrainerMemberDetail.fromJson(
          _json(ranking: 999, nickName: '은우님'),
        )!;

        expect(detail.showsDivider, isFalse);
      });

      test('둘 다 없음 → 숨긴다', () {
        final detail = TrainerMemberDetail.fromJson(_json())!;

        expect(detail.showsDivider, isFalse);
      });

      test('별칭이 빈 문자열이면 웹처럼 falsy로 본다', () {
        final detail = TrainerMemberDetail.fromJson(
          _json(ranking: 3, nickName: ''),
        )!;

        expect(detail.showsDivider, isFalse);
      });
    });

    group('식단 카드 두 분기 — 서로의 반대가 아니다', () {
      test('dietId가 있으면 오늘 식단', () {
        final detail = TrainerMemberDetail.fromJson(
          _json(diet: _dietJson(dietId: 11)),
        )!;

        expect(detail.hasTodayDiet, isTrue);
        expect(detail.hasNoDietYet, isFalse);
      });

      test('dietId가 null이면 등록 식단', () {
        final detail = TrainerMemberDetail.fromJson(
          _json(diet: _dietJson(dietId: null)),
        )!;

        expect(detail.hasTodayDiet, isFalse);
        expect(detail.hasNoDietYet, isTrue);
      });

      test('dietId가 0이면 **둘 다 아니다**', () {
        // 웹 `{dietId && ...}`는 0을 falsy로 보고, `{dietId === null && ...}`는
        // 0에 걸리지 않는다 → 식단 자리가 통째로 빈다.
        final detail = TrainerMemberDetail.fromJson(
          _json(diet: _dietJson(dietId: 0)),
        )!;

        expect(detail.hasTodayDiet, isFalse);
        expect(detail.hasNoDietYet, isFalse);
      });

      test('diet 자체가 null이면 둘 다 아니다', () {
        // 웹은 `memberInfo.diet.dietId`를 가드 없이 읽어 TypeError로 화면이
        // 통째로 죽는다. 여기서는 식단 카드를 안 그리는 것으로 흡수한다
        // (명시적 이탈 — `deferred-minors.md`).
        final detail = TrainerMemberDetail.fromJson(_json(diet: null))!;

        expect(detail.diet, isNull);
        expect(detail.hasTodayDiet, isFalse);
        expect(detail.hasNoDietYet, isFalse);
      });
    });

    test('course·point는 없으면 null이다', () {
      final detail = TrainerMemberDetail.fromJson(_json())!;

      expect(detail.course, isNull);
      expect(detail.point, isNull);
    });

    test('프로필 ranking과 rank.ranking은 다른 필드다', () {
      // 웹도 둘을 따로 읽는다 — 프로필 줄은 `memberInfo.ranking`,
      // 포인트 카드는 `memberInfo.rank.ranking`이다. 합치면 한쪽이 틀린다.
      final detail = TrainerMemberDetail.fromJson(
        _json(
          ranking: 3,
          rank: <String, dynamic>{
            'ranking': 7,
            'lastMonthRanking': 9,
            'totalMemberCnt': 20,
          },
        ),
      )!;

      expect(detail.ranking, 3);
      expect(detail.rank.ranking, 7);
    });
  });
}
