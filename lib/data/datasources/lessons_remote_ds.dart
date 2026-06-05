import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_interceptor.dart';
import '../../core/network/dio_client.dart';
import '../models/lesson_model.dart';

class LessonsRemoteDataSource {
  LessonsRemoteDataSource._();
  static final LessonsRemoteDataSource instance = LessonsRemoteDataSource._();

  Dio get _dio => DioClient.instance.dio;

  /// Unwrap { success: true, data: ... } envelope from plugin responses
  Object? _unwrap(Object? body) {
    if (body is Map<String, dynamic>) {
      if (body['success'] == true  && body.containsKey('data')) return body['data'];
      if (body['status'] == 'success' && body.containsKey('data')) return body['data'];
    }
    return body;
  }

  /// Always throws — return type Never lets Dart know all paths are covered
  Never _handleDioError(DioException e, {int courseId = 0}) {
    final body       = e.response?.data;
    final statusCode = e.response?.statusCode;
    String? serverMsg, serverCode;
    if (body is Map) {
      serverMsg  = body['message'] as String?;
      serverCode = body['code']    as String?;
    }
    if (statusCode == 401) {
      throw UnauthorizedFailure(serverMsg ?? 'يرجى تسجيل الدخول');
    }
    if (statusCode == 403) {
      final isEnrollmentGate =
          serverCode == 'not_enrolled' ||
          serverCode == 'tutor_course_not_enrolled';
      if (isEnrollmentGate) {
        throw EnrollmentFailure(
          courseId: courseId,
          message:  serverMsg ?? 'يجب التسجيل في هذا الكورس أولاً',
        );
      }
      throw ServerFailure(serverMsg ?? 'غير مصرح بالوصول', statusCode: 403);
    }
    if (statusCode == 402) {
      throw ServerFailure(serverMsg ?? 'هذا الكورس مدفوع', statusCode: 402);
    }
    if (statusCode == 429) {
      throw const ServerFailure('طلبات كثيرة، انتظر قليلاً', statusCode: 429);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      throw const NetworkFailure();
    }
    throw ServerFailure(serverMsg ?? dioErrorMessage(e), statusCode: statusCode);
  }

  // ── Topics ────────────────────────────────────────────────────────────────

  Future<List<TopicModel>> getTopics(int courseId) async {
    try {
      final res = await _dio.get(
        ApiConstants.topicsEndpoint,
        queryParameters: {'course_id': courseId},
      );
      final raw = _unwrap(res.data);
      if (raw == null) return const <TopicModel>[];

      // Plugin returns: { success: true, data: [ {topic...}, ... ] }
      // Each topic already contains its lessons array
      final List<dynamic> list = raw is List
          ? raw
          : (raw is Map && raw['topics'] is List
              ? raw['topics'] as List<dynamic>
              : <dynamic>[raw]);

      return list
          .map((e) => TopicModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      return _handleDioError(e, courseId: courseId);
    }
  }

  // ── Lessons ───────────────────────────────────────────────────────────────

  Future<List<LessonModel>> getLessons(int topicId) async {
    try {
      final res = await _dio.get(
        ApiConstants.lessonsEndpoint,
        queryParameters: {'topic_id': topicId},
      );
      final raw = _unwrap(res.data);
      if (raw == null) return const <LessonModel>[];

      final List<dynamic> list = raw is List ? raw : <dynamic>[raw];

      return list
          .map((e) => LessonModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  Future<bool> markLessonComplete(int lessonId, int courseId) async {
    try {
      final res = await _dio.post(
        ApiConstants.markLessonCompleteEndpoint,
        data: {'lesson_id': lessonId, 'course_id': courseId},
      );
      final raw = _unwrap(res.data);
      return raw is Map
          ? raw['completed'] == true || raw['status'] == 'success'
          : (res.statusCode ?? 0) < 300;
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  Future<bool> markCourseComplete(int courseId) async {
    try {
      final res = await _dio.post(
        ApiConstants.markCourseCompleteEndpoint,
        data: {'course_id': courseId},
      );
      final raw = _unwrap(res.data);
      return raw is Map
          ? raw['completed'] == true || raw['status'] == 'success'
          : (res.statusCode ?? 0) < 300;
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }
}
