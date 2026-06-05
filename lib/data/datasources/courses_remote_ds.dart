import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/course_page.dart';
import '../models/course_model.dart';
import '../models/course_page_model.dart';
import 'dio_helpers.dart';

class CoursesRemoteDataSource {
  CoursesRemoteDataSource._();
  static final CoursesRemoteDataSource instance = CoursesRemoteDataSource._();

  Dio get _dio => DioClient.instance.dio;

  Object? _unwrap(Object? body) {
    if (body is Map<String, dynamic>) {
      if (body['status'] == 'success' && body.containsKey('data')) return body['data'];
      if (body['success'] == true     && body.containsKey('data')) return body['data'];
    }
    return body;
  }

  Future<CoursePage> getCourses({
    int page    = 1,
    int perPage = ApiConstants.defaultPerPage,
  }) async {
    try {
      final res = await _dio.get(
        ApiConstants.coursesEndpoint,
        queryParameters: {
          'page':     page,
          'per_page': perPage,
        },
      );
      final unwrapped = _unwrap(res.data);

      // Plugin returns app_ok_paged: { success, data:[], total, total_pages, page }
      if (unwrapped is Map<String, dynamic>) {
        return CoursePageModel.fromJson(unwrapped, page);
      }
      if (unwrapped is List) {
        final List<CourseModel> courses = unwrapped
            .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return CoursePage(
          courses:     courses,
          total:       courses.length,
          totalPages:  1,
          currentPage: page,
        );
      }
      return CoursePage.empty;
    } on DioException catch (e) {
      // FIX: return keyword ensures Dart knows Never propagates
      return handleDioError(e);
    }
  }

  Future<CourseModel> getCourseDetail(int courseId) async {
    try {
      final res = await _dio.get(ApiConstants.courseDetailEndpoint(courseId));
      final raw = _unwrap(res.data);
      if (raw is! Map<String, dynamic>) {
        throw const ServerFailure('استجابة غير صالحة من الخادم');
      }
      return CourseModel.fromJson(raw);
    } on DioException catch (e) {
      return handleDioError(e);
    }
  }

  Future<bool> enrollCourse(int courseId) async {
    try {
      final res = await _dio.post(
        ApiConstants.enrollmentEndpoint,
        data: {'course_id': courseId},
      );
      final raw = _unwrap(res.data);
      return raw is Map
          ? raw['enrolled'] == true || raw['status'] == 'success'
          : (res.statusCode ?? 0) < 300;
    } on DioException catch (e) {
      return handleDioError(e);
    }
  }
}
