import 'package:flutter/foundation.dart';

/// 웹 `useMyInfoQuery`(`GET /api/v1/members/me`)의 응답
/// = 백엔드 `MemberInfoResult`.
///
/// ## 12필드 중 여섯을 담는다
///
/// 담는 것: `name` · `userId` · `email` · `socialType` · `profile.fileUrl` ·
/// `gym.name` · **알림 설정 4종**. 마이페이지 화면들이 실제로 읽는 값 전부다.
///
/// **담지 않는 것과 그 이유**
/// - `id` · `memberType` — 화면이 읽지 않는다. 역할 분기는 라우터가
///   `AuthUser`(로그인 응답)로 이미 하고 있다.
/// - `/student/mypage/alarm`이 생기면서 **알림 설정 4종을 추가로 담는다**
///   (2026-09-15). 약속대로 쓰는 화면이 생긴 뒤에 넣었다.
/// - `profile`의 나머지 — 애초에 응답에 없다. **웹 타입은 여섯 필드
///   (`fileName`·`originalName`·`extension`·`fileSize` 포함)를 선언하지만
///   백엔드 `ProfileDto`는 `{id, fileUrl}` 둘뿐이다**(서베이 BUG-18).
/// - 웹 타입의 `age`·`height`·`weight`·`delYn` — **응답에 존재하지 않는다**
///   (서베이 BUG-19). 선언만 있고 서버가 주지 않는 필드다.
///
/// 근거: `docs/student-mypage-survey.md` §4-1, 그리고 2026-09-15 실측 응답.
@immutable
class MemberInfo {
  const MemberInfo({
    this.name = '',
    this.userId = '',
    this.email = '',
    this.socialType = '',
    this.profileFileUrl,
    this.gymName = '',
    this.pushAlarmStatus = '',
    this.communityAlarmStatus = '',
    this.feedbackAlarmStatus = '',
    this.scheduleNoticeStatus = '',
  });

  /// 알림이 켜져 있음을 뜻하는 서버 값.
  ///
  /// 꺼짐은 **`DISABLE`**이다 — `DISABLED`가 아니다(백엔드 `AlarmStatus`
  /// enum의 철자 그대로).
  static const String alarmEnabled = 'ENABLED';

  factory MemberInfo.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      return const MemberInfo();
    }
    final gym = data['gym'];
    final profile = data['profile'];
    return MemberInfo(
      name: data['name'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      email: data['email'] as String? ?? '',
      socialType: data['socialType'] as String? ?? '',
      // 백엔드 `ProfileDto`는 `{id, fileUrl}`이고 **null 가능**하다
      // (`MemberInfoResult.java:26~27`). 실측 응답도 `"profile": null`이었다.
      profileFileUrl: profile is Map<String, dynamic>
          ? profile['fileUrl'] as String?
          : null,
      // 웹은 `userInfo?.gym.name`으로 **`gym`은 가드하지 않는다** —
      // 타입이 non-optional이라서다. 서버가 null을 주면 웹은 TypeError지만
      // (헬스장 미선택 계정은 라우터가 `/select-gym`으로 돌려보내므로 실제로
      // 도달하지 않는다) 앱에서는 빈 문자열로 받는다.
      //
      // **`GymDto`라 id 필드명이 `id`다**(`GymResult`의 `gymId`가 아니다).
      // 목록용 `Gym`으로 받으면 비-null 캐스트가 터진다 —
      // 근거는 `test/entity/gym/gym_test.dart`.
      gymName: gym is Map<String, dynamic> ? gym['name'] as String? ?? '' : '',
      pushAlarmStatus: data['pushAlarmStatus'] as String? ?? '',
      communityAlarmStatus: data['communityAlarmStatus'] as String? ?? '',
      feedbackAlarmStatus: data['feedbackAlarmStatus'] as String? ?? '',
      scheduleNoticeStatus: data['scheduleNoticeStatus'] as String? ?? '',
    );
  }

  final String name;
  final String userId;
  final String email;

  /// `NONE` · `KAKAO` · `NAVER` · `GOOGLE` · `APPLE`
  /// (백엔드 `SocialType.java:11~15`).
  ///
  /// enum으로 좁히지 않는다 — 화면이 하는 판정은 [isSocialAccount] 하나뿐이고,
  /// 모르는 값이 오면 enum은 파싱에서 던지지만 문자열은 그대로 흘려 보낸다.
  final String socialType;

  /// 백엔드 `ProfileDto.fileUrl`. 없으면 화면이 아바타 자산으로 대체한다.
  final String? profileFileUrl;

  /// 헤더에 찍을 헬스장 이름. 아직 안 왔으면 빈 문자열이다 —
  /// 웹도 `userInfo`가 오기 전에는 그 자리가 비어 있다.
  final String gymName;

  /// 알림 설정 4종. `ENABLED` 또는 `DISABLE`이다.
  ///
  /// **enum으로 좁히지 않고 원문을 들고 있는다.** 웹 화면이 두 가지를
  /// 따로 보기 때문이다:
  /// - `data?.pushAlarmStatus &&` — **값이 있는가**(스위치를 그릴지)
  /// - `=== 'ENABLED'` — **켜져 있는가**
  ///
  /// 빈 문자열이면 앞쪽이 거짓이 되어 스위치가 사라진다. bool로 바꾸면
  /// 그 구분이 사라진다.
  final String pushAlarmStatus;
  final String communityAlarmStatus;
  final String feedbackAlarmStatus;
  final String scheduleNoticeStatus;

  /// 웹 `const isSocialAccount = data?.socialType !== 'NONE';`
  /// (`EditMyInfoPage.tsx:81`).
  ///
  /// **모르는 값·빈 값은 소셜로 친다 — 웹 버그를 그대로 옮긴 것이다.**
  /// 웹에서 `data`가 아직 없으면 `undefined !== 'NONE'`이 참이라 로딩 중에는
  /// 언제나 소셜 계정으로 판정된다(서베이 BUG-5). 지금은 두 화면 다
  /// `{data && ...}`로 가려서 드러나지 않지만, **로딩 UI를 넣는 순간
  /// 드러난다.** 고칠 때는 웹과 앱을 함께 바꾼다.
  bool get isSocialAccount => socialType != 'NONE';

  /// 프로필 카드 부제에 찍는 값.
  ///
  /// 웹 `data?.socialType === 'NONE' ? data.userId : data?.email`
  /// (`StudentMyPage.tsx:50`) — **일반 계정은 아이디, 소셜 계정은 이메일**이다.
  String get accountLabel => isSocialAccount ? email : userId;
}
