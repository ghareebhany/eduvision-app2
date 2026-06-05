import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/course.dart';
import '../entities/course_page.dart';
import '../entities/lesson.dart';
import '../entities/review.dart';
import '../entities/user.dart';
import '../repositories/i_auth_repository.dart';
import '../repositories/i_course_repository.dart';
import '../repositories/i_profile_repository.dart';

// ── Auth use cases ────────────────────────────────────────────────────────────

class LoginUseCase {
  final IAuthRepository _repo;
  const LoginUseCase(this._repo);

  Future<Either<Failure, User>> call(String username, String password) =>
      _repo.login(username, password);
}

class LogoutUseCase {
  final IAuthRepository _repo;
  const LogoutUseCase(this._repo);

  Future<Either<Failure, bool>> call() => _repo.logout();
}

// ── Course use cases ──────────────────────────────────────────────────────────

class GetCoursesUseCase {
  final ICourseRepository _repo;
  const GetCoursesUseCase(this._repo);

  Future<Either<Failure, CoursePage>> call({
    int page = 1,
    int perPage = 10,
  }) =>
      _repo.getCourses(page: page, perPage: perPage);
}

class GetCourseDetailUseCase {
  final ICourseRepository _repo;
  const GetCourseDetailUseCase(this._repo);

  Future<Either<Failure, Course>> call(int courseId) =>
      _repo.getCourseDetail(courseId);
}

class GetTopicsUseCase {
  final ICourseRepository _repo;
  const GetTopicsUseCase(this._repo);

  Future<Either<Failure, List<Topic>>> call(int courseId) =>
      _repo.getTopics(courseId);
}

class GetLessonsUseCase {
  final ICourseRepository _repo;
  const GetLessonsUseCase(this._repo);

  Future<Either<Failure, List<Lesson>>> call(int topicId) =>
      _repo.getLessons(topicId);
}

class MarkLessonCompleteUseCase {
  final ICourseRepository _repo;
  const MarkLessonCompleteUseCase(this._repo);

  Future<Either<Failure, bool>> call(int lessonId, int courseId) =>
      _repo.markLessonComplete(lessonId, courseId);
}

class MarkCourseCompleteUseCase {
  final ICourseRepository _repo;
  const MarkCourseCompleteUseCase(this._repo);

  Future<Either<Failure, bool>> call(int courseId) =>
      _repo.markCourseComplete(courseId);
}

class EnrollCourseUseCase {
  final ICourseRepository _repo;
  const EnrollCourseUseCase(this._repo);

  Future<Either<Failure, bool>> call(int courseId) =>
      _repo.enrollCourse(courseId);
}

// ── Profile use cases ─────────────────────────────────────────────────────────

class GetProfileUseCase {
  final IProfileRepository _repo;
  const GetProfileUseCase(this._repo);

  Future<Either<Failure, User>> call(int userId) => _repo.getProfile(userId);
}

class UpdateProfileUseCase {
  final IProfileRepository _repo;
  const UpdateProfileUseCase(this._repo);

  Future<Either<Failure, bool>> call(Map<String, dynamic> data) =>
      _repo.updateProfile(data);
}

class GetInstructorInfoUseCase {
  final IProfileRepository _repo;
  const GetInstructorInfoUseCase(this._repo);

  Future<Either<Failure, User>> call(int instructorId) =>
      _repo.getInstructorInfo(instructorId);
}

class GetReviewsUseCase {
  final IProfileRepository _repo;
  const GetReviewsUseCase(this._repo);

  Future<Either<Failure, List<Review>>> call({int? courseId, int page = 1}) =>
      _repo.getReviews(courseId: courseId, page: page);
}
