import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/user.dart';
import 'auth_provider.dart';
import 'di_providers.dart';

// ── Profile Provider ──────────────────────────────────────────────────────────
// FIX: يراقب authProvider مباشرة — لا يُنفَّذ حتى تكتمل المصادقة.
// FIX: إذا فشل الـ API يرجع بيانات من SecureStorage بدل إبقاء الـ loading.

final profileProvider = FutureProvider.family<User, int>((ref, userId) async {
  // انتظر حتى تكتمل المصادقة
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) {
    throw Exception('يرجى تسجيل الدخول أولاً');
  }

  try {
    final result = await ref.read(getProfileUseCaseProvider).call(userId);
    return result.fold(
      (failure) {
        // FIX: إذا فشل API بـ EmptyResponseFailure أو ServerFailure
        // ارجع بيانات المستخدم المخزّنة في SecureStorage
        if (failure is EmptyResponseFailure || failure is ServerFailure) {
          return authState.user;
        }
        throw Exception(failure.message);
      },
      (user) => user,
    );
  } catch (e) {
    // FIX: أي خطأ غير متوقع → ارجع بيانات الجلسة الحالية بدل إبقاء loading
    return authState.user;
  }
});

// ── Instructor info ───────────────────────────────────────────────────────────

final instructorProvider =
    FutureProvider.family<User, int>((ref, instructorId) async {
  final result =
      await ref.read(getInstructorInfoUseCaseProvider).call(instructorId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (user) => user,
  );
});

// ── Reviews ───────────────────────────────────────────────────────────────────

final reviewsProvider =
    FutureProvider.family<List<Review>, int>((ref, courseId) async {
  final result = await ref
      .read(getReviewsUseCaseProvider)
      .call(courseId: courseId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (reviews) => reviews,
  );
});

// ── Update profile notifier ───────────────────────────────────────────────────

class UpdateProfileState {
  final bool isLoading;
  final bool success;
  final String? error;
  const UpdateProfileState({
    this.isLoading = false,
    this.success = false,
    this.error,
  });
}

class UpdateProfileNotifier extends StateNotifier<UpdateProfileState> {
  final Ref _ref;
  UpdateProfileNotifier(this._ref) : super(const UpdateProfileState());

  Future<void> update(Map<String, dynamic> data) async {
    state = const UpdateProfileState(isLoading: true);
    final result = await _ref.read(updateProfileUseCaseProvider).call(data);
    result.fold(
      (f) => state = UpdateProfileState(error: f.message),
      (_) => state = const UpdateProfileState(success: true),
    );
  }

  void reset() => state = const UpdateProfileState();
}

final updateProfileProvider =
    StateNotifierProvider<UpdateProfileNotifier, UpdateProfileState>(
  (ref) => UpdateProfileNotifier(ref),
);
