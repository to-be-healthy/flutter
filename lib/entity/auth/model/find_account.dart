import 'package:flutter/foundation.dart';

/// 웹 `src/entity/auth/regexp.ts` 대응.
///
/// 웹 정규식을 **글자 그대로** 옮긴다. 더 엄격하거나 관대한 검사로
/// 바꾸면 같은 입력에 대해 웹은 보내고 앱은 막는(또는 그 반대) 화면이 된다.
abstract final class AuthRegExp {
  /// `/^[가-힣a-zA-Z]+$/` — 한글 또는 영문만. 공백·숫자를 허용하지 않는다.
  static final RegExp name = RegExp(r'^[가-힣a-zA-Z]+$');

  /// `/^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/`.
  ///
  /// TLD를 2~4자로 제한하는 것은 웹의 제약 그대로다(`.museum`·`.invalid`
  /// 같은 5자 이상 TLD는 웹에서도 거부된다).
  static final RegExp email = RegExp(
    r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$',
  );
}

/// 웹 `FindIdRequest` = `FindPasswordRequest` = `{name, email}`.
///
/// 두 엔드포인트가 같은 본문을 쓴다 — 실제로 캡처한 HAR 두 건의 본문이
/// 키 순서까지 동일하다(`har/find-id.har`, `har/find-password.har`).
@immutable
class FindAccountRequest {
  const FindAccountRequest({required this.name, required this.email});

  final String name;
  final String email;

  /// 웹은 react-hook-form의 폼 객체를 그대로 `mutate(form)`으로 넘긴다 —
  /// **trim하지 않는다.** 여기서 다듬으면 골든과 본문이 어긋난다.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'email': email,
  };
}

/// 웹 `FindIdResponse {userId, createdAt, socialType}`.
@immutable
class FindIdResponse {
  const FindIdResponse({
    required this.userId,
    required this.socialType,
    this.createdAt,
  });

  factory FindIdResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw FormatException(
        '아이디 찾기 응답에 data가 없다: ${json['status']} ${json['message']}',
      );
    }
    final createdAt = data['createdAt'];
    return FindIdResponse(
      userId: data['userId'] as String? ?? '',
      // 소셜 가입자면 웹이 `socialType !== 'NONE'` 분기로 가며 userId를
      // 쓰지 않는다. 그래서 userId가 비어 올 수 있다고 보고 ''로 받는다.
      socialType: data['socialType'] as String? ?? socialTypeNone,
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }

  final String userId;

  /// 가입일자. 파싱에 실패하면 null이고, 그때 화면은 날짜 줄을 비운다 —
  /// 아이디를 보여주는 것이 이 화면의 목적이라 날짜 때문에 죽으면 안 된다.
  final DateTime? createdAt;

  /// 'NONE' | 'NAVER' | 'GOOGLE' | 'KAKAO' | 'APPLE'.
  final String socialType;
}

/// 웹 `FindPasswordResponse = Pick<FindIdResponse, 'socialType'>`.
@immutable
class FindPasswordResponse {
  const FindPasswordResponse({required this.socialType});

  factory FindPasswordResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw FormatException(
        '비밀번호 찾기 응답에 data가 없다: ${json['status']} ${json['message']}',
      );
    }
    return FindPasswordResponse(
      socialType: data['socialType'] as String? ?? socialTypeNone,
    );
  }

  final String socialType;
}

/// 소셜 가입이 아님을 뜻하는 값. 웹 `SocialType`의 'NONE'.
const String socialTypeNone = 'NONE';

/// 웹 `dayjs(createdAt).format('YYYY.MM.DD')` 대응.
///
/// `intl` 패키지를 끌어오지 않는다 — 로케일 규칙이 필요 없는 고정 포맷이고,
/// 여기서 의존성을 늘리면 62개 화면이 그 선택을 물려받는다.
String formatYearMonthDay(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}.$month.$day';
}
