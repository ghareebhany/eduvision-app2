import 'package:dio/dio.dart';
import '../utils/secure_storage.dart';

/// JWT error codes that indicate an INVALID/EXPIRED token
/// (not just "unauthorized endpoint")
const _kJwtInvalidCodes = {
  'jwt_auth_invalid_token',
  'jwt_auth_no_auth_header',
  'jwt_auth_bad_auth_header',
  'jwt_auth_bad_config',
  'jwt_auth_obsolete_token',
};

class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra['skipAuth'] == true;
    if (!skipAuth) {
      final token = await SecureStorageService.instance.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final skipAuth = err.requestOptions.extra['skipAuth'] == true;

    if (!skipAuth && err.response?.statusCode == 401) {
      // Fix #1: Only logout on REAL token invalidity,
      // NOT on every 401 (e.g. "unauthorized endpoint" is not a session issue)
      final body = err.response?.data;
      final code = body is Map<String, dynamic> ? body['code'] as String? : null;

      final isTokenInvalid = code != null && _kJwtInvalidCodes.contains(code);

      if (isTokenInvalid) {
        await SecureStorageService.instance.clearAll();
      }
      // If code is unknown/null on 401, we do NOT force logout
      // — let the caller handle it as an auth error
    }
    handler.next(err);
  }
}

String dioErrorMessage(DioException e) {
  final body = e.response?.data;
  if (body is Map) {
    final msg = body['message'] as String?;
    if (msg != null && msg.isNotEmpty) {
      return msg
          .replaceAll('&#8220;', '"')
          .replaceAll('&#8221;', '"')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>');
    }
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'انتهت مهلة الاتصال، يرجى المحاولة مجدداً';
    case DioExceptionType.connectionError:
      return 'لا يوجد اتصال بالإنترنت';
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      if (code == 401) return 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول';
      if (code == 403) return 'ليس لديك صلاحية للوصول';
      if (code == 404) return 'المورد غير موجود';
      if (code == 429) return 'طلبات كثيرة جداً، انتظر قليلاً';
      if (code != null && code >= 500) return 'خطأ في الخادم';
      return 'خطأ في الاستجابة ($code)';
    case DioExceptionType.cancel:
      return 'تم إلغاء الطلب';
    default:
      return 'حدث خطأ غير متوقع';
  }
}
