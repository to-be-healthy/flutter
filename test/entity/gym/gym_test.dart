import 'package:flutter_test/flutter_test.dart';
import 'package:geonganghaejim/entity/gym/model/gym.dart';
import 'package:geonganghaejim/entity/home/model/student_home.dart';
import 'package:geonganghaejim/entity/member/model/member_info.dart';

/// **백엔드에 헬스장 DTO가 둘이고 id 필드명이 다르다.**
///
/// | 백엔드 record | id 필드 | 쓰는 응답 |
/// |---|---|---|
/// | `GymResult` | `gymId` | `GET /api/v1/gyms` (목록) |
/// | `GymDto` | **`id`** | `members/me` · `home/student` · `home/trainer`의 `gym` |
///
/// 둘 다 같은 도메인 객체에서 `gym.getId()`·`gym.getName()`으로 만들어지는데
/// **필드 이름만 다르다.** 웹은 JS라 없는 키가 `undefined`로 조용히 넘어가고
/// 어차피 `gym.name`만 읽으므로 이 차이가 드러나지 않는다.
///
/// 앱에서는 드러난다. 한동안 `Gym.fromJson`이 `json['gymId'] as int`로 둘을
/// 같이 받으려 했고, `GymDto`에는 그 키가 없어 **비-null 캐스트가 터졌다.**
/// 호출부의 `catch (_)`가 그 예외를 삼켜서 홈이 통째로 빈 화면이 됐다.
///
/// 해법은 `Gym`을 넓히는 것이 아니라 **둘을 섞지 않는 것**이다.
/// `Gym`은 목록(`GymResult`) 전용이고, `GymDto`를 받는 쪽은 실제로 쓰는 값
/// 하나(**이름**)만 담는다. 그래야 목록·등록 경로의 `gymId`가 non-null로
/// 남는다([[GymSelectList]]의 타일 키와 `POST /api/v1/gyms/{gymId}`가 그것을
/// 요구한다).
///
/// 2026-09-15 실측(`GET /api/v1/members/me`):
/// `"gym":{"id":1,"name":"건강해짐 홍대점"}`
void main() {
  group('Gym — 목록(GymResult) 전용이다', () {
    test('gymId 와 name 을 읽는다', () {
      final gym = Gym.fromJson(<String, dynamic>{
        'gymId': 1,
        'name': '건강해짐 강남점',
      });

      expect(gym.gymId, 1);
      expect(gym.name, '건강해짐 강남점');
    });

    // 이 단언이 **두 DTO를 섞지 않는다는 결정을 고정한다.** `id`도 받게
    // 넓히면 `gymId`가 nullable이 되어야 하고, 그 null이 타일 키와 등록
    // POST까지 번진다.
    test('GymDto 모양(id)은 받지 않는다 — 목록 응답에는 그 모양이 오지 않는다', () {
      expect(
        () => Gym.fromJson(<String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('GymDto 를 받는 쪽은 이름만 담는다', () {
    test('MemberInfo 가 실측 응답의 gym.name 을 읽는다', () {
      final me = MemberInfo.fromJson(<String, dynamic>{
        'id': 6,
        'userId': 'healthy-student0',
        'name': '차은우',
        'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 홍대점'},
        'memberType': 'STUDENT',
      });

      expect(me.gymName, '건강해짐 홍대점');
    });

    // **이것이 가장 아팠던 자리다.** `Gym.fromJson`이 여기서 터지면
    // `StudentHome.fromJson` 전체가 던지고, 로더의 `catch (_)`가 삼켜서
    // **홈의 모든 섹션이 빈 상태로 그려졌다** — 헬스장 이름 하나가 아니라.
    test('StudentHome 이 실측 모양의 gym 때문에 통째로 실패하지 않는다', () {
      final home = StudentHome.fromJson(<String, dynamic>{
        'gym': <String, dynamic>{'id': 1, 'name': '건강해짐 강남점'},
        'point': <String, dynamic>{'monthPoint': 1200},
      });

      expect(home.gymName, '건강해짐 강남점');
      // 뒤따르는 필드가 살아 있는지까지 본다 — 파싱이 중간에 던지면
      // 이 단언이 먼저 깨진다.
      expect(home.point?.monthPoint, 1200);
    });

    test('gym 이 null이면 빈 이름이다', () {
      expect(StudentHome.fromJson(<String, dynamic>{'gym': null}).gymName, '');
      expect(MemberInfo.fromJson(<String, dynamic>{'gym': null}).gymName, '');
    });

    test('gym.name 이 없으면 빈 이름이다', () {
      expect(
        StudentHome.fromJson(<String, dynamic>{
          'gym': <String, dynamic>{'id': 1},
        }).gymName,
        '',
      );
    });
  });
}
