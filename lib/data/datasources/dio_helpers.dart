import 'package:dio/dio.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_interceptor.dart';

/// Shared Dio error handler — used by all RemoteDataSources.
/// Returns [Never] so the compiler knows every path throws.
Never handleDioError(DioException e, {int courseId = 0}) {
  final body = e.response?.data;
  String? serverMsg;
  String? serverCode;
  if (body is Map) {
    serverMsg  = body['message'] as String?;
    serverCode = body['code']    as String?;
  }

  final code = e.response?.statusCode;
  if (code == 401) throw UnauthorizedFailure(serverMsg ?? 'يرجى تسجيل الدخول');
  if (code == 402) throw ServerFailure(serverMsg ?? 'هذا الكورس مدفوع', statusCode: 402);

  // BUG FIX #1: كانت 403 تُعالَج كـ ServerFailure عامة
  // الحل: كشف not_enrolled وإطلاق EnrollmentFailure حتى يعرضها الـ UI صح
  if (code == 403) {
    final isEnrollmentGate =
        serverCode == 'not_enrolled' ||
        serverCode == 'tutor_course_not_enrolled' ||
        serverCode == 'forbidden';
    if (isEnrollmentGate || courseId > 0) {
      throw EnrollmentFailure(
        courseId: courseId,
        message: serverMsg ?? 'يجب التسجيل في هذا الكورس أولاً',
      );
    }
    throw ServerFailure(serverMsg ?? 'غير مصرح', statusCode: 403);
  }

  if (code == 429) throw const ServerFailure('طلبات كثيرة، انتظر قليلاً', statusCode: 429);
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    throw const NetworkFailure();
  }
  throw ServerFailure(serverMsg ?? dioErrorMessage(e), statusCode: code);
}
