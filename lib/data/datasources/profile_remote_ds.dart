import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import 'dio_helpers.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource._();
  static final ProfileRemoteDataSource instance = ProfileRemoteDataSource._();

  Dio get _dio => DioClient.instance.dio;

  Object? _unwrap(Object? body) {
    if (body is Map<String, dynamic>) {
      if (body['success'] == true && body.containsKey('data')) return body['data'];
      if (body['status'] == 'success' && body.containsKey('data')) return body['data'];
    }
    return body;
  }

  /// FIX: استخدم /tutor/v1/profile/{userId} المعياري بدل /app/v1/profile/me
  /// /app/v1/profile/me endpoint مخصص وغير مضمون الوجود على كل خادم Tutor LMS
  Future<UserModel> getProfile(int userId) async {
    try {
      // استخدم /app/v1/profile/me — يُعيد المستخدم الحالي من JWT بدون ID في URL
      final res = await _dio.get(ApiConstants.profileMeEndpoint);
      final raw = _unwrap(res.data);
      if (raw is! Map<String, dynamic>) throw const EmptyResponseFailure();
      return UserModel.fromProfileJson(raw);
    } on DioException catch (e) {
      return handleDioError(e);
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(ApiConstants.updateProfileEndpoint, data: data);
      final raw = _unwrap(res.data);
      return raw is Map ? raw['updated'] == true : (res.statusCode ?? 0) < 300;
    } on DioException catch (e) {
      return handleDioError(e);
    }
  }

  Future<UserModel> getInstructorInfo(int instructorId) async {
    try {
      final res = await _dio.get(ApiConstants.instructorEndpoint(instructorId));
      final raw = _unwrap(res.data);
      if (raw is! Map<String, dynamic>) throw const EmptyResponseFailure();
      return UserModel.fromProfileJson(raw);
    } on DioException catch (e) {
      return handleDioError(e);
    }
  }

  Future<List<ReviewModel>> getReviews({int? courseId, int page = 1}) async {
    try {
      final res = await _dio.get(
        ApiConstants.reviewsEndpoint,
        queryParameters: {
          if (courseId != null) 'course_id': courseId,
          'page': page,
          'per_page': ApiConstants.defaultPerPage,
        },
      );
      final raw = _unwrap(res.data);
      if (raw == null) return [];
      final list = raw is List ? raw : [raw];
      return list
          .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      return handleDioError(e);
    }
  }
}
