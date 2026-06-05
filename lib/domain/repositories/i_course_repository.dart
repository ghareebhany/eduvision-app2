import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/course.dart';
import '../entities/course_page.dart';
import '../entities/lesson.dart';

abstract class ICourseRepository {
  Future<Either<Failure, CoursePage>> getCourses({int page, int perPage});
  Future<Either<Failure, Course>> getCourseDetail(int courseId);
  Future<Either<Failure, List<Topic>>> getTopics(int courseId);
  Future<Either<Failure, List<Lesson>>> getLessons(int topicId);
  Future<Either<Failure, bool>> markLessonComplete(int lessonId, int courseId);
  Future<Either<Failure, bool>> markCourseComplete(int courseId);
  Future<Either<Failure, bool>> enrollCourse(int courseId);
}
