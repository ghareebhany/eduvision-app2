import 'package:equatable/equatable.dart';

/// معلومات كورس مختصرة داخل الحزمة
class BundleCourse extends Equatable {
  final int    id;
  final String title;
  final String thumbnail;
  final bool   isEnrolled;

  const BundleCourse({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.isEnrolled,
  });

  @override
  List<Object?> get props => [id, isEnrolled];
}

/// حزمة دورات (Bundle)
class Bundle extends Equatable {
  final int              id;
  final String           title;
  final String           description;
  final String           thumbnail;
  final int              courseCount;
  final List<BundleCourse> courses;
  final bool             isEnrolled; // true إذا كان مسجّلاً في أي كورس من الحزمة
  final String           permalink;

  const Bundle({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.courseCount,
    required this.courses,
    required this.isEnrolled,
    required this.permalink,
  });

  @override
  List<Object?> get props => [id, isEnrolled];
}
