import 'package:dio/dio.dart';

import '../model/course_history_page.dart';

/// 웹 `feature/course/api/queries.ts` + `mutations.ts`.
///
/// 조회 하나(`GET /members/{id}/course`)와 뮤테이션 셋(`/course`)이 컨트롤러가
/// 서로 다르지만, 화면 하나가 넷을 다 쓰고 전부 수강권 도메인이라 한 클래스다.
class CourseApi {
  CourseApi(this._dio);

  /// 백엔드 `MemberController.java:123` — 트레이너 전용.
  static String historyPath(Object memberId) =>
      '/api/v1/members/$memberId/course';

  /// 백엔드 `CourseController` — 셋 다 트레이너 전용, 전부 `ApiResult<Void>`.
  static const String coursePath = '/api/v1/course';

  static String courseIdPath(Object courseId) => '$coursePath/$courseId';

  /// 웹 `ITEMS_PER_PAGE`(`StudentCourseDetailPage.tsx:49`).
  static const int pageSize = 20;

  final Dio _dio;

  /// 웹 `useStudentCourseDetailQuery` — `useInfiniteQuery`다.
  ///
  /// **쿼리 셋을 전부 명시해서 보낸다**(`page`·`size`·`searchDate`). 골든이
  /// 쿼리스트링까지 대조하므로 하나라도 빠지면 패리티가 깨진다.
  ///
  /// [page]는 웹의 `getNextPageParam: (lastPage, allPages) => allPages.length`
  /// 를 그대로 옮긴 것이다 — **이미 받은 페이지 수**가 다음 페이지 번호다.
  Future<CourseHistoryPage> history({
    required Object memberId,
    required String searchDate,
    int page = 0,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      historyPath(memberId),
      queryParameters: {
        'page': page,
        'size': pageSize,
        'searchDate': searchDate,
      },
    );
    return CourseHistoryPage.fromJson(response.data?['data']);
  }

  /// 웹 `useRegisterStudentCourseMutation` — `POST /api/v1/course`.
  ///
  /// 백엔드 `CourseAddCommand {Long memberId(@NotNull), int lessonCnt(@Positive)}`.
  /// 성공 문구는 **서버 `message`를 그대로** 띄운다.
  Future<String?> register({
    required Object memberId,
    required int lessonCnt,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      coursePath,
      data: {'memberId': memberId, 'lessonCnt': lessonCnt},
    );
    return response.data?['message'] as String?;
  }

  /// 웹 `useAddStudentCourseMutation` — `PATCH /api/v1/course/{courseId}`.
  ///
  /// 백엔드 `CourseUpdateCommand {memberId, calculation, type, int updateCnt}`.
  ///
  /// **`updateCnt`를 int로 보낸다.** 웹은 입력 상태가 `string`이라 `"5"`를
  /// 보내고 Jackson이 강제변환해 준다(서베이 §4.3⑯). 여기서 문자열을 보낼
  /// 이유가 없다 — 계약이 `int`다.
  Future<void> addCount({
    required Object courseId,
    required Object memberId,
    required int updateCnt,
  }) async {
    await _dio.patch<Map<String, dynamic>>(
      courseIdPath(courseId),
      data: {
        'memberId': memberId,
        'calculation': 'PLUS',
        'type': 'PLUS_CNT',
        'updateCnt': updateCnt,
      },
    );
  }

  /// 웹 `useDeleteStudentCourseMutation` — `DELETE /api/v1/course/{courseId}`.
  ///
  /// **그 회원의 수강권을 통째로 지운다**(서베이 §2.1 복구 불가). 골든을
  /// 만들지 않은 이유이고, 요청 모양은 계약 테스트가 고정한다.
  Future<String?> delete(Object courseId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      courseIdPath(courseId),
    );
    return response.data?['message'] as String?;
  }
}
