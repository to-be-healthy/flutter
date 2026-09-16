/// 서버가 정수 필드를 문자열로 주는 경우까지 흡수한다.
///
/// 관용이 아니라 실용이다 — `openapi/api-docs.json`이 홈·회원관리 응답
/// 스키마를 비워 두고 있어(`200: {}`) 타입 보장이 문서에 없다. 숫자 하나가
/// 문자열로 와서 화면 전체가 죽는 것보다 낫다.
///
/// 원래 `entity/home/model/student_home.dart`의 파일 전용 `_asInt`였다.
/// `/trainer/manage/[memberId]`가 같은 DTO(`CourseDto`·`PointDto`·`RankDto`·
/// `DietDto`)를 다른 엔드포인트로 받으면서 두 번째 사용처가 생겨 올렸다.
int? asIntOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
