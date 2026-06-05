import 'course.dart';

/// Fix #2: Pagination-aware response model
/// Replaces raw List<Course> so UI can properly implement infinite scroll
class CoursePage {
  final List<Course> courses;
  final int total;
  final int totalPages;
  final int currentPage;

  const CoursePage({
    required this.courses,
    required this.total,
    required this.totalPages,
    required this.currentPage,
  });

  bool get hasNextPage => currentPage < totalPages;
  bool get isLastPage  => currentPage >= totalPages;

  CoursePage copyWithAdditional(CoursePage next) => CoursePage(
        courses:     [...courses, ...next.courses],
        total:       next.total,
        totalPages:  next.totalPages,
        currentPage: next.currentPage,
      );

  static const empty = CoursePage(
    courses: [], total: 0, totalPages: 0, currentPage: 1,
  );
}
