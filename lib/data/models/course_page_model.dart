import '../../domain/entities/course_page.dart';
import 'course_model.dart';

/// Fix #2: Parses paginated courses response from /app/v1/courses
/// Server returns: {courses: [...], total: n, total_pages: n}
class CoursePageModel extends CoursePage {
  const CoursePageModel({
    required super.courses,
    required super.total,
    required super.totalPages,
    required super.currentPage,
  });

  factory CoursePageModel.fromJson(Map<String, dynamic> json, int requestedPage) {
    final rawList = json['courses'] as List<dynamic>? ?? 
                    json['data']   as List<dynamic>? ?? [];

    final courses = rawList
        .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return CoursePageModel(
      courses:     courses,
      total:       _parseInt(json['total']),
      totalPages:  _parseInt(json['total_pages']),
      currentPage: _parseInt(json['page'] ?? requestedPage),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
