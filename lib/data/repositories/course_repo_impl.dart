import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/cache_manager.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_page.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/repositories/i_course_repository.dart';
import '../datasources/courses_remote_ds.dart';
import '../datasources/lessons_remote_ds.dart';

class CourseRepositoryImpl implements ICourseRepository {
  final CoursesRemoteDataSource _coursesDs;
  final LessonsRemoteDataSource _lessonsDs;
  final CacheManager _cache;

  CourseRepositoryImpl({
    CoursesRemoteDataSource? coursesDs,
    LessonsRemoteDataSource? lessonsDs,
    CacheManager? cache,
  })  : _coursesDs = coursesDs ?? CoursesRemoteDataSource.instance,
        _lessonsDs = lessonsDs ?? LessonsRemoteDataSource.instance,
        _cache     = cache     ?? CacheManager.instance;

  // ── Courses ───────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, CoursePage>> getCourses({
    int page = 1,
    int perPage = 10,
  }) async {
    final cacheKey = 'courses_p${page}_pp$perPage';
    final cached = _cache.get<CoursePage>(cacheKey);
    if (cached != null) return Right(cached);

    try {
      final coursePage = await _coursesDs.getCourses(page: page, perPage: perPage);
      _cache.set(cacheKey, coursePage);
      return Right(coursePage);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Course>> getCourseDetail(int courseId) async {
    // BUG FIX #2: لا تستخدم cache لتفاصيل الكورس
    // السبب: بعد التسجيل يبقى is_enrolled=false في الـ cache فيظل الزر أحمر
    // الحل: اجلب دائماً من الـ backend مباشرةً

    try {
      final model = await _coursesDs.getCourseDetail(courseId);
      return Right(model);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ── Topics ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Topic>>> getTopics(int courseId) async {
    // BUG FIX #2 (continued): لا cache للـ topics أيضاً بعد التسجيل
    // السبب: نفس المشكلة — topics تعود فارغة أو بـ 403 من cache قديم

    try {
      final models = await _lessonsDs.getTopics(courseId);
      return Right(models);
    } on Failure catch (f) {
      // EnrollmentFailure passes through untouched → UI detects it
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ── Lessons ───────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Lesson>>> getLessons(int topicId) async {
    final cacheKey = 'lessons_$topicId';
    final cached = _cache.get<List<Lesson>>(cacheKey);
    if (cached != null) return Right(cached);

    try {
      final models = await _lessonsDs.getLessons(topicId);
      _cache.set(cacheKey, List<Lesson>.from(models));
      return Right(models);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, bool>> markLessonComplete(
      int lessonId, int courseId) async {
    try {
      final ok = await _lessonsDs.markLessonComplete(lessonId, courseId);
      _cache.invalidateCourseData();
      return Right(ok);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> markCourseComplete(int courseId) async {
    try {
      final ok = await _lessonsDs.markCourseComplete(courseId);
      _cache.invalidateCourseData();
      return Right(ok);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ── Enrollment ────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, bool>> enrollCourse(int courseId) async {
    try {
      final ok = await _coursesDs.enrollCourse(courseId);
      // امسح كل الـ cache المتعلق بالكورس فور التسجيل
      _cache.invalidateCourseData();
      _cache.invalidate('course_$courseId');
      return Right(ok);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
