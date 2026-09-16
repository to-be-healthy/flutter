import 'package:flutter/foundation.dart';

import '../../../core/json/json_number.dart';

/// 백엔드 `DietDto` 중 **홈이 쓰는 세 끼니만**. 웹 `HomeDietData`.
@immutable
class HomeDiet {
  const HomeDiet({
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    this.dietId,
  });

  static HomeDiet? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return HomeDiet(
      // **널 허용 캐스트다.** `as int`로 못박으면 이 필드를 쓰지 않는
      // 학생 홈까지 함께 죽는다 — `Gym`을 넓히다 홈을 죽인 적이 있다.
      dietId: asIntOrNull(json['dietId']),
      breakfast: DietMeal.fromJson(json['breakfast'], MealType.breakfast),
      lunch: DietMeal.fromJson(json['lunch'], MealType.lunch),
      dinner: DietMeal.fromJson(json['dinner'], MealType.dinner),
    );
  }

  /// 학생 홈은 쓰지 않고 **`/trainer/manage/[memberId]`만** 쓴다.
  ///
  /// 웹 S2가 `memberInfo.diet.dietId`로 `오늘 식단`(값 있음)과
  /// `등록 식단`(`=== null`)을 가른다. **둘 다 아닌 경우가 있다** —
  /// `dietId`가 `0`이거나 키 자체가 없으면 두 카드 모두 안 그려진다.
  final int? dietId;

  final DietMeal breakfast;
  final DietMeal lunch;
  final DietMeal dinner;

  /// 웹이 `breakfast`·`lunch`·`dinner` 순서로 타일 셋을 그린다.
  List<DietMeal> get meals => <DietMeal>[breakfast, lunch, dinner];
}

/// 웹 `DietWithFasting`. 백엔드 `DietDetailDto`.
@immutable
class DietMeal {
  const DietMeal({required this.type, required this.isFasting, this.fileUrl});

  /// 끼니가 통째로 null이어도 **빈 끼니**로 흡수한다.
  ///
  /// 백엔드 `DietDto`의 기본 생성자가 세 끼니에 `new DietDetailDto()`를 넣긴
  /// 하지만, 그 안의 필드는 비어 있을 수 있다. 여기서 null을 흘리면 타일
  /// 셋 중 하나만 없는 응답에 화면이 죽는다.
  static DietMeal fromJson(Object? json, MealType type) {
    if (json is! Map<String, dynamic>) {
      return DietMeal(type: type, isFasting: false);
    }
    final file = json['dietFile'];
    return DietMeal(
      type: type,
      isFasting: json['fast'] == true,
      fileUrl: file is Map<String, dynamic> ? file['fileUrl'] as String? : null,
    );
  }

  final MealType type;
  final bool isFasting;
  final String? fileUrl;

  /// 웹 타일의 3분기 중 어느 것인지.
  ///
  /// 순서가 중요하다 — **단식이 사진을 이긴다.** 웹도 `{diet.fast && ...}`를
  /// 먼저 평가하므로, 단식이면서 사진이 있는 데이터는 단식 타일로 그려진다.
  DietTile get tile {
    if (isFasting) {
      return DietTile.fasting;
    }
    return (fileUrl != null && fileUrl!.isNotEmpty)
        ? DietTile.photo
        : DietTile.empty;
  }
}

enum MealType { breakfast, lunch, dinner }

enum DietTile { fasting, photo, empty }
