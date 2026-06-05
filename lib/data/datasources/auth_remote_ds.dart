import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/secure_storage.dart';
import '../models/user_model.dart';
import 'dio_helpers.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource._();
  static final AuthRemoteDataSource instance = AuthRemoteDataSource._();

  Dio get _dio => DioClient.instance.dio;

  /// تسجيل الدخول مع معالجة تلقائية لمشكلة "تجاوز حد الجلسات النشطة" (Tutor LMS)
  /// ملاحظة: الإضافة المخصصة في الموقع تقوم بمسح الجلسات تلقائياً عبر hook 'authenticate'
  Future<UserModel> login(String username, String password) async {
    try {
      return await _doLogin(username, password);
    } on ServerFailure catch (e) {
      // إذا حدث خطأ "تجاوز الجلسات" رغم الـ hook (حالة نادرة)، نحاول المسح يدوياً وإعادة المحاولة
      final isSessionLimit = _isSessionLimitError(e.message, e.statusCode);

      if (isSessionLimit) {
        await _clearSessionsAndRetry(username, password);
        return await _doLogin(username, password);
      }
      rethrow;
    }
  }

  /// الاستدعاء الفعلي لـ JWT login
  Future<UserModel> _doLogin(String username, String password) async {
    try {
      final res = await _dio.post(
        ApiConstants.loginEndpoint,
        data: {'username': username, 'password': password},
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'skipAuth': true},
        ),
      );
      final body = res.data as Map<String, dynamic>? ?? {};

      // ── تحقق من رسالة Tutor LMS في الـ response body ────────────────────
      final msg    = body['message'] as String? ?? '';
      final code   = body['code']    as String? ?? '';
      final status = (body['data'] as Map?)?['status'] as int? ?? 0;

      if (_isSessionLimitError(msg, status) || _isSessionLimitError(code, status)) {
        throw ServerFailure(msg.isNotEmpty ? msg : 'session_limit', statusCode: 403);
      }

      if (body.containsKey('code') && !body.containsKey('token')) {
        throw ServerFailure(
          msg.isNotEmpty ? msg : 'خطأ في تسجيل الدخول',
          statusCode: status > 0 ? status : 401,
        );
      }
      if (body['token'] == null) {
        throw const ServerFailure('لم يتم إرسال رمز المصادقة من الخادم');
      }
      return UserModel.fromLoginJson(body);
    } on DioException catch (e) {
      // ── استخرج رسالة الخطأ من الـ response body ─────────────────────────
      final respData = e.response?.data;
      if (respData is Map) {
        final msg    = respData['message'] as String? ?? '';
        final status = e.response?.statusCode ?? 0;
        if (_isSessionLimitError(msg, status)) {
          throw ServerFailure(msg, statusCode: 403);
        }
        if (msg.isNotEmpty) {
          throw ServerFailure(msg, statusCode: status);
        }
      }
      return handleDioError(e);
    }
  }

  /// مسح الجلسات عبر API ثم الانتظار قليلاً
  Future<void> _clearSessionsAndRetry(String username, String password) async {
    try {
      await _dio.post(
        ApiConstants.clearSessionsEndpoint,
        data: {'username': username, 'password': password},
        options: Options(extra: {'skipAuth': true}),
      );
      // انتظر ثانية واحدة حتى يُطبَّق المسح على الـ server
      await Future<void>.delayed(const Duration(milliseconds: 800));
    } catch (_) {
      // إذا فشل المسح — سنحاول الدخول مباشرة على أي حال
    }
  }

  /// يكتشف ما إذا كان الخطأ بسبب حد الجلسات النشطة
  bool _isSessionLimitError(String msg, int? statusCode) {
    if (msg.isEmpty) return false;
    final lower = msg.toLowerCase();
    return lower.contains('exceeded') ||
        lower.contains('active session') ||
        lower.contains('active login') ||
        lower.contains('session limit') ||
        lower.contains('تجاوزت') ||
        lower.contains('الحد الأقصى') ||
        lower.contains('جلسات') ||
        msg.contains('tutor_active_session') ||
        msg.contains('session_limit');
  }

  /// يجلب WP nonce بعد تسجيل الدخول
  Future<void> fetchNonce() async {
    try {
      final res = await _dio.get(ApiConstants.nonceEndpoint);
      final body = res.data;
      String? nonce;
      if (body is Map) {
        nonce = body['nonce'] as String? ??
            (body['data'] as Map?)?['nonce'] as String?;
      }
      if (nonce != null && nonce.isNotEmpty) {
        DioClient.instance.setNonce(nonce);
        await SecureStorageService.instance.saveNonce(nonce);
      }
    } catch (_) {
      // non-blocking
    }
  }
}
