import '../../domain/entities/bundle.dart';

class BundleCourseModel extends BundleCourse {
  const BundleCourseModel({
    required super.id,
    required super.title,
    required super.thumbnail,
    required super.isEnrolled,
  });

  factory BundleCourseModel.fromJson(Map<String, dynamic> json) {
    return BundleCourseModel(
      id:         _parseInt(json['id']),
      title:      json['title']     as String? ?? '',
      thumbnail:  json['thumbnail'] as String? ?? '',
      isEnrolled: json['is_enrolled'] == true || json['is_enrolled'] == 1,
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}

class BundleModel extends Bundle {
  const BundleModel({
    required super.id,
    required super.title,
    required super.description,
    required super.thumbnail,
    required super.courseCount,
    required super.courses,
    required super.isEnrolled,
    required super.permalink,
  });

  factory BundleModel.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'] as List<dynamic>? ?? [];
    return BundleModel(
      id:          _parseInt(json['id']),
      title:       json['title']       as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnail:   json['thumbnail']   as String? ?? '',
      courseCount: _parseInt(json['course_count']),
      courses:     rawCourses
          .map((c) => BundleCourseModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      isEnrolled:  json['is_enrolled'] == true || json['is_enrolled'] == 1,
      permalink:   json['permalink']   as String? ?? '',
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
