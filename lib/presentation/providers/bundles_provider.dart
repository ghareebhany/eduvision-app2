import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/bundle.dart';
import '../../data/models/bundle_model.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class BundlesState {
  final List<Bundle> bundles;
  final bool         isLoading;
  final String?      error;

  const BundlesState({
    this.bundles   = const [],
    this.isLoading = false,
    this.error,
  });

  BundlesState copyWith({
    List<Bundle>? bundles,
    bool?         isLoading,
    String?       error,
  }) => BundlesState(
    bundles:   bundles   ?? this.bundles,
    isLoading: isLoading ?? this.isLoading,
    error:     error,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class BundlesNotifier extends StateNotifier<BundlesState> {
  BundlesNotifier() : super(const BundlesState());

  Future<void> fetch({bool refresh = false}) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await DioClient.instance.dio.get(
        ApiConstants.bundlesEndpoint,
      );
      final data = response.data as Map<String, dynamic>;
      final raw  = (data['data']?['bundles'] ?? data['bundles']) as List<dynamic>? ?? [];
      final list = raw
          .map((b) => BundleModel.fromJson(b as Map<String, dynamic>))
          .toList();
      state = BundlesState(bundles: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'تعذّر تحميل الحزم، تحقق من اتصالك',
      );
    }
  }

  /// تحديث حالة التسجيل محلياً بعد استخدام كود بنجاح
  void markEnrolled(int bundleId, List<int> enrolledCourseIds) {
    final updated = state.bundles.map((b) {
      if (b.id != bundleId) return b;
      final updatedCourses = b.courses.map((c) {
        if (enrolledCourseIds.contains(c.id)) {
          return BundleCourseModel(
            id: c.id, title: c.title,
            thumbnail: c.thumbnail, isEnrolled: true,
          );
        }
        return c;
      }).toList();
      return BundleModel(
        id: b.id, title: b.title, description: b.description,
        thumbnail: b.thumbnail, courseCount: b.courseCount,
        courses: updatedCourses, isEnrolled: true,
        permalink: b.permalink,
      );
    }).toList();
    state = state.copyWith(bundles: updated);
  }
}

final bundlesProvider =
    StateNotifierProvider<BundlesNotifier, BundlesState>(
  (_) => BundlesNotifier(),
);
