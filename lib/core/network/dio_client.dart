import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../utils/secure_storage.dart';
import 'api_interceptor.dart';

class DioClient {
  DioClient._();
  static final DioClient _instance = DioClient._();
  static DioClient get instance => _instance;

  late final Dio _dio;
  bool _initialized = false;

  Dio get dio {
    if (!_initialized) _init();
    return _dio;
  }

  void setNonce(String nonce) {
    _dio.options.headers['X-WP-Nonce'] = nonce;
  }

  void clearNonce() {
    _dio.options.headers.remove('X-WP-Nonce');
  }

  /// Restore persisted nonce from SecureStorage on app restart.
  /// Called from auth_provider._checkInitialAuth() after confirming token exists.
  /// Without this, Tutor LMS Pro /students/{id}/dashboard returns 403.
  Future<void> restoreNonce() async {
    final saved = await SecureStorageService.instance.getNonce();
    if (saved != null && saved.isNotEmpty) {
      setNonce(saved);
    }
  }

  void _init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      AuthInterceptor(),
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        compact: true,
      ),
    ]);

    _initialized = true;
  }
}
