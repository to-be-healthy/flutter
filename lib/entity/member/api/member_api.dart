import 'package:dio/dio.dart';

import '../model/member_info.dart';
import '../model/trainer_info.dart';

/// 웹 `feature/schedule/api/queries.ts`의 `useCheckTrainerMemberMappingQuery`.
class MemberApi {
  MemberApi(this._dio);

  /// 백엔드 `MemberController`의 `@GetMapping("/trainer-mapping")`.
  /// 응답은 `ApiResult<TrainerMappingResult>` = `{ "mapped": bool }`.
  static const String trainerMappingPath = '/api/v1/members/trainer-mapping';

  /// 백엔드 `MemberController`의 `@GetMapping("/trainer-mapping/info")`.
  /// `@PreAuthorize("hasAuthority('ROLE_STUDENT')")`이다.
  static const String trainerMappingInfoPath = '$trainerMappingPath/info';

  /// 백엔드 `MemberController`의 `@GetMapping("/me")`.
  static const String mePath = '/api/v1/members/me';

  /// 백엔드 `MemberCommandController`의 `@PostMapping("/logout")`.
  static const String logoutPath = '/api/v1/members/logout';

  /// 비밀번호 확인(POST)과 변경(PATCH)이 **같은 경로를 메서드로 가른다.**
  static const String passwordPath = '/api/v1/members/password';

  /// 백엔드 `MemberCommandController`의 `@PatchMapping("/name")`.
  static const String namePath = '/api/v1/members/name';

  /// 백엔드 `MemberCommandController`의 `@PatchMapping("/email")`.
  static const String emailPath = '/api/v1/members/email';

  /// 알림 토글. **값을 본문이 아니라 경로에 담는다** —
  /// `PATCH /api/v1/members/alarm/{type}/{status}`.
  static const String alarmPath = '/api/v1/members/alarm';

  /// 백엔드 `MemberCommandController`의 `@PostMapping("/delete")`.
  ///
  /// **웹은 이 요청을 `entity/auth`에 두었다**(`useDeleteAccountMutation`).
  /// 여기서는 경로를 따라 `MemberApi`에 둔다 — `logout`과 같은 컨트롤러다.
  static const String deletePath = '/api/v1/members/delete';

  final Dio _dio;

  /// 이 회원에게 지정된 트레이너가 있으면 true.
  ///
  /// 웹에서 이 요청은 **하단 네비가 마운트될 때** 자동으로 나간다
  /// (`useCheckTrainerMemberMappingQuery`에 `enabled` 옵션이 없다). 그래서
  /// 홈 진입 골든 3건 중 하나이고, 수업예약 탭을 누르면 한 번 더 나간다
  /// (`staleTime: 0`).
  Future<bool> trainerMapping() async {
    final response = await _dio.get<Map<String, dynamic>>(trainerMappingPath);
    final data = response.data?['data'];
    return data is Map && data['mapped'] == true;
  }

  /// 웹 `useMyInfoQuery`. 트레이너 홈이 **헤더의 헬스장 이름 하나** 때문에
  /// 부르는 요청이고, 골든 `home-trainer`의 첫 번째다.
  ///
  /// 학생 홈은 같은 정보를 `home/student` 응답의 `gym` 필드로 해결한다 —
  /// 트레이너 응답에도 `gym`이 있지만 웹은 쓰지 않는다. **요청을 줄이면
  /// 골든이 3건에서 2건이 되어 패리티가 깨진다.**
  Future<MemberInfo> me() async {
    final response = await _dio.get<Map<String, dynamic>>(mePath);
    return MemberInfo.fromJson(response.data?['data']);
  }

  /// 웹 `useLogOutMutation`. 서버가 refreshToken과 fcmToken을 지운다.
  ///
  /// **응답에 본문이 없다.** 컨트롤러가 `ApiResult`가 아니라 `void`를
  /// 반환하므로(`MemberCommandController.java:51~54`) 이 프로젝트의 다른
  /// 요청과 달리 껍데기가 없다 — 그래서 `Map`으로 받지 않는다. 웹 타입은
  /// `BaseResponse<boolean>`으로 선언해 두었지만 실제로는 빈 문자열이 오고,
  /// 소비 측이 값을 보지 않아 드러나지 않는다(서베이 §4-5).
  ///
  /// 던지면 화면이 토스트를 띄우고 **로그아웃하지 않는다** — 웹도 같다.
  Future<void> logout() async {
    await _dio.post<void>(logoutPath);
  }

  /// 웹 `useDeleteAccountMutation`. **계정을 실제로 지운다.**
  ///
  /// 응답은 `ApiResult<String>`(`"회원 탈퇴 되었습니다."`)인데 웹 타입은
  /// `BaseResponse<boolean>`으로 선언해 두었다 — 소비 측이 값을 보지 않아
  /// 드러나지 않는 불일치다(서베이 §4-5). 여기서도 값을 쓰지 않는다.
  ///
  /// **골든이 없다.** 공유 체험 계정을 지우는 뮤테이션이라 캡처 자체를
  /// 할 수 없다(`/select-gym`의 등록 POST와 같은 부류) — 요청의 모양은
  /// `student_my_page_leave_page_test.dart`의 계약 테스트가 고정한다.
  Future<void> deleteAccount() async {
    await _dio.post<void>(deletePath);
  }

  /// 웹 `useStudentMypageTrainerInfoQuery`.
  ///
  /// **매핑이 없으면 `data`가 null이라 null을 돌려준다.** 화면이 그것으로
  /// 빈 상태를 고른다 — 에러가 아니다.
  Future<TrainerInfo?> trainerMappingInfo() async {
    final response = await _dio.get<Map<String, dynamic>>(
      trainerMappingInfoPath,
    );
    return TrainerInfo.fromJson(response.data?['data']);
  }

  /// 웹 `useChangeEmailMutation`.
  ///
  /// 본문 키는 **`email`과 `emailKey`**다(백엔드 `CommandChangeEmail`).
  /// `emailKey`가 사용자가 입력한 인증번호다 — 이름이 `code`가 아니다.
  Future<void> changeEmail({
    required String email,
    required String emailKey,
  }) async {
    await _dio.patch<Map<String, dynamic>>(
      emailPath,
      data: <String, dynamic>{'email': email, 'emailKey': emailKey},
    );
  }

  /// 웹 `useToggleAlarmStatusMutation`.
  ///
  /// [type]은 `PUSH` · `COMMUNITY` · `FEEDBACK` · `SCHEDULENOTICE`,
  /// 상태는 **`ENABLED` / `DISABLE`**이다(`DISABLED`가 아니다 —
  /// 백엔드 `AlarmStatus` enum의 철자 그대로다).
  ///
  /// 응답은 `ApiResult<MemberChangeAlarmResult>`이고 그 `type`은 enum 이름이
  /// 아니라 **한글 설명**(`푸시`·`커뮤니티`…)이다. 웹은 그 값을 쓰지 않고
  /// 성공 후 `members/me`를 다시 부른다 — 여기서도 같다.
  Future<void> toggleAlarm({
    required String type,
    required bool enabled,
  }) async {
    final status = enabled ? 'ENABLED' : 'DISABLE';
    await _dio.patch<Map<String, dynamic>>('$alarmPath/$type/$status');
  }

  /// 웹 `useChangeMyNameMutation`.
  ///
  /// 응답은 `ApiResult<CommandChangeNameResult{memberId, name}>`인데 웹
  /// 타입은 `BaseResponse<string>`으로 선언해 두었다 — 소비 측이 값을 보지
  /// 않아 드러나지 않는 불일치다(서베이 §4-5). 여기서도 쓰지 않는다.
  Future<void> changeName(String name) async {
    await _dio.patch<Map<String, dynamic>>(
      namePath,
      data: <String, dynamic>{'name': name},
    );
  }

  /// 웹 `useVerifyPasswordMutation`. 현재 비밀번호가 맞는지 묻는다.
  ///
  /// 계정을 바꾸지 않는 **읽기성 요청**이지만 비밀번호를 본문에 담으므로
  /// 골든을 만들지 않았다 — 캡처하면 HAR에 평문이 남는다.
  ///
  /// 틀리면 서버가 400과 `"비밀번호가 일치하지 않습니다."`를 준다
  /// (`MemberService.java:48`). 즉 **false가 돌아오는 경로는 사실상 없고**,
  /// 웹도 `if (data)`로 한 번 더 가드한다. 그 가드를 그대로 옮긴다.
  Future<bool> verifyPassword(String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      passwordPath,
      data: <String, dynamic>{'password': password},
    );
    return response.data?['data'] == true;
  }

  /// 웹 `useChangePasswordMutation`.
  ///
  /// **본문 키 이름이 `changePassword1`·`changePassword2`다**(백엔드
  /// `CommandChangeMemberPassword`). `newPassword`류로 바꾸면 서버가 못
  /// 알아듣는다.
  ///
  /// 두 값이 다를 때의 검증은 **서버도 한다** — 화면이 버튼을 막는 것과
  /// 별개다.
  Future<void> changePassword({
    required String password,
    required String confirmPassword,
  }) async {
    await _dio.patch<Map<String, dynamic>>(
      passwordPath,
      data: <String, dynamic>{
        'changePassword1': password,
        'changePassword2': confirmPassword,
      },
    );
  }
}
