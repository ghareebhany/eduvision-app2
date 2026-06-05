import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../core/utils/secure_storage.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/network/dio_client.dart';
import 'di_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthInitial()) {
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    try {
      final repo      = _ref.read(authRepositoryProvider);
      final isLogged  = await repo.isLoggedIn();

      if (!isLogged) {
        state = const AuthUnauthenticated();
        return;
      }

      final userId      = await repo.getCurrentUserId();
      final token       = await SecureStorageService.instance.getToken() ?? '';
      final email       = await SecureStorageService.instance.getUserEmail() ?? '';
      final displayName = await SecureStorageService.instance.getDisplayName() ?? '';

      if (userId == null || userId == 0 || token.isEmpty) {
        // Corrupt storage — force clean logout
        await SecureStorageService.instance.clearAll();
        state = const AuthUnauthenticated();
        return;
      }

      CacheManager.instance.setCurrentUser(userId);

      // ── الإصلاح الجوهري لـ "غير مسموح" ──────────────────────────────────
      // Tutor LMS Pro /students/{id}/dashboard و /courses تتطلب
      // X-WP-Nonce + JWT معاً. الـ Nonce يُفقد من ذاكرة DioClient عند
      // إعادة تشغيل التطبيق — هنا نستعيده من SecureStorage.
      await DioClient.instance.restoreNonce();

      state = AuthAuthenticated(
        User(
          id:          userId,
          email:       email,
          displayName: displayName,
          avatarUrl:   '',
          token:       token,
        ),
      );
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login(String username, String password) async {
    state = const AuthLoading();
    final result = await _ref
        .read(loginUseCaseProvider)
        .call(username, password);

    result.fold(
      (failure) => state = AuthError(failure.message),
      (user) {
        // FIX: اضبط AuthAuthenticated أولاً فوراً حتى تنتقل الشاشات
        // بدون انتظار fetchNonce — الـ nonce يُحفظ في الـ repo بشكل async
        state = AuthAuthenticated(user);
      },
    );
  }

  Future<void> logout() async {
    await _ref.read(logoutUseCaseProvider).call();
    state = const AuthUnauthenticated();
  }

  void forceLogout() => state = const AuthUnauthenticated();
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);

final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authProvider) is AuthAuthenticated,
);
