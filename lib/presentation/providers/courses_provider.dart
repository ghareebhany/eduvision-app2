import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/cache_manager.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/lesson.dart';
import 'di_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class CoursesState {
  final List<Course> courses;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final int totalPages;
  final int total;
  final bool hasMore;

  const CoursesState({
    this.courses       = const [],
    this.isLoading     = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage   = 1,
    this.totalPages    = 1,
    this.total         = 0,
    this.hasMore       = true,
  });

  CoursesState copyWith({
    List<Course>? courses,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    int? totalPages,
    int? total,
    bool? hasMore,
  }) => CoursesState(
        courses:       courses       ?? this.courses,
        isLoading:     isLoading     ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error:         error,
        currentPage:   currentPage   ?? this.currentPage,
        totalPages:    totalPages    ?? this.totalPages,
        total:         total         ?? this.total,
        hasMore:       hasMore       ?? this.hasMore,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CoursesNotifier extends StateNotifier<CoursesState> {
  final Ref _ref;
  CoursesNotifier(this._ref) : super(const CoursesState());

  Future<void> fetchCourses({bool refresh = false}) async {
    if (refresh) {
      CacheManager.instance.invalidateCourseData();
      state = const CoursesState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    final result = await _ref
        .read(getCoursesUseCaseProvider)
        .call(page: 1, perPage: ApiConstants.defaultPerPage);

    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (page) => state = CoursesState(
        courses:     page.courses,
        isLoading:   false,
        currentPage: page.currentPage,
        totalPages:  page.totalPages,
        total:       page.total,
        hasMore:     page.hasNextPage,
      ),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);

    final result = await _ref
        .read(getCoursesUseCaseProvider)
        .call(page: state.currentPage + 1, perPage: ApiConstants.defaultPerPage);

    result.fold(
      (f) => state = state.copyWith(isLoadingMore: false, error: f.message),
      (page) => state = state.copyWith(
        courses:       [...state.courses, ...page.courses],
        isLoadingMore: false,
        currentPage:   page.currentPage,
        totalPages:    page.totalPages,
        total:         page.total,
        hasMore:       page.hasNextPage,
      ),
    );
  }
}

final coursesProvider = StateNotifierProvider<CoursesNotifier, CoursesState>(
  (ref) => CoursesNotifier(ref),
);

// ── Course detail ─────────────────────────────────────────────────────────────
// FIX: أُزيل ref.watch(enrollmentOverrideProvider) من هنا.
// كان يُعيد تشغيل الـ FutureProvider بالكامل (بما فيه الـ API call) عند كل
// تغيير في الـ override، مما يخلق race conditions وحلقات لا نهائية.
// الـ optimistic update الآن يُعالَج محلياً في الشاشة فقط عبر _enrolledLocally.

final courseDetailProvider = FutureProvider.family<Course, int>((ref, id) async {
  final result = await ref.read(getCourseDetailUseCaseProvider).call(id);
  return result.fold(
    (f) => throw Exception(f.message),
    (c) => c,
  );
});

// ── Topics & Lessons ──────────────────────────────────────────────────────────

final topicsProvider = FutureProvider.family<List<Topic>, int>((ref, courseId) async {
  final result = await ref.read(getTopicsUseCaseProvider).call(courseId);
  return result.fold(
    (f) {
      if (f is EnrollmentFailure) throw f;
      throw Exception(f.message);
    },
    (t) => t,
  );
});

final lessonsProvider = FutureProvider.family<List<Lesson>, int>((ref, topicId) async {
  final result = await ref.read(getLessonsUseCaseProvider).call(topicId);
  return result.fold(
    (f) => throw Exception(f.message),
    (l) => l,
  );
});
