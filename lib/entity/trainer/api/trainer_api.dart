import 'package:dio/dio.dart';

import '../model/trainer_member.dart';
import '../model/trainer_member_detail.dart';

/// `/api/v1/trainers/**` — 트레이너 전용 엔드포인트.
///
/// **`MemberApi`와 나눈 기준은 도메인이 아니라 경로다.** 이 앱의 다른
/// `*_api.dart`도 그렇게 갈라져 있다(`TrainerInfo`는 회원이 부르는
/// `/members/trainer-mapping/info`라 `MemberApi`에 있다). 여기 모이는 것은
/// 백엔드 `TrainerController`가 `ROLE_TRAINER`로 막아 둔 요청들이고,
/// `/trainer/manage` 계열 19개 화면이 전부 이 껍데기를 쓴다.
class TrainerApi {
  TrainerApi(this._dio);

  /// 백엔드 `TrainerController.java:106`. `ROLE_TRAINER` 전용.
  static const String membersPath = '/api/v1/trainers/members';

  /// 백엔드 `TrainerController.java:97`. `ROLE_TRAINER` 전용.
  static String memberPath(Object memberId) => '$membersPath/$memberId';

  /// 회원-트레이너 매핑 해제. **복구할 수 없다.**
  static String memberDeletePath(Object memberId) => memberPath(memberId);

  /// 환불 삭제. **회원 정보·운동기록·예약내역·수강권이 함께 사라진다.**
  static String memberRefundPath(Object memberId) =>
      '${memberPath(memberId)}/refund';

  final Dio _dio;

  /// 웹 `useRegisteredStudentsQuery`(`feature/manage/api/queries.ts:23`).
  ///
  /// **회원이 없으면 `[]`가 아니라 null이다** — 화면이 그것으로 "등록된
  /// 회원이 없습니다"와 "검색 결과가 없습니다"를 가른다.
  ///
  /// **페이지 파라미터를 보내지 않는다.** 서버는 `@PageableDefault(size=100)`
  /// 이라 101번째 회원부터 잘린다(BUG-44). 웹도 보내지 않으므로 그대로
  /// 옮긴다 — 여기서 `size`를 붙이면 골든의 쿼리가 웹과 어긋난다.
  Future<List<TrainerMember>?> members() async {
    final response = await _dio.get<Map<String, dynamic>>(membersPath);
    return TrainerMember.fromListJson(response.data?['data']);
  }

  /// 웹 `useStudentDetailQuery`(`feature/manage/api/queries.ts:35`).
  ///
  /// 못 찾으면 `data`가 null이고, 화면은 그 상태에서 **아무것도 그리지
  /// 않는다**(웹 `{memberInfo && ...}`가 헤더까지 감싼다).
  Future<TrainerMemberDetail?> member(Object memberId) async {
    final response = await _dio.get<Map<String, dynamic>>(memberPath(memberId));
    return TrainerMemberDetail.fromJson(response.data?['data']);
  }

  /// 웹 `useDeleteStudentMutation`. **회원-트레이너 매핑을 끊는다.**
  ///
  /// **골든이 없다.** 공유 체험 계정의 회원을 실제로 떼어내는 뮤테이션이라
  /// 캡처할 수 없다(`/select-gym` 등록 POST와 같은 부류). 요청의 모양은
  /// `trainer_manage_member_page_test.dart`의 계약 테스트가 고정한다.
  Future<void> deleteMember(Object memberId) async {
    await _dio.delete<Map<String, dynamic>>(memberDeletePath(memberId));
  }

  /// 웹 `useDeleteRefundStudentMutation`. **환불 삭제 — 복구 불가.**
  ///
  /// 응답 `message`를 성공 토스트로 그대로 띄운다(웹
  /// `onSuccess: ({message}) => successToast(message)`).
  /// 골든이 없는 이유는 [deleteMember]와 같다.
  Future<String?> deleteMemberWithRefund(Object memberId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      memberRefundPath(memberId),
    );
    return response.data?['message'] as String?;
  }
}
