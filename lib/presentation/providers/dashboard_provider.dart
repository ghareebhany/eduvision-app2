import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_interceptor.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_page.dart';
import 'auth_provider.dart';

// ── Current User ID ───────────────────────────────────────────────────────────
// Single source of truth — reactive to AuthState.
// Returns 0 when unauthenticated so providers can guard safely.

final currentUserIdProvider = Provider<int>((ref) {
  final state = ref.watch(authProvider);
  return state is AuthAuthenticated ? state.user.id : 0;
});

// ── Dashboard Stats ───────────────────────────────────────────────────────────

class InProgressCourse {
  final int id;
  final String title;
  final String thumbnail;
  final int completedPercent;
  final int completedLessons;
  final int totalLessons;

  const InProgressCourse({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.completedPercent,
    required this.completedLessons,
    required this.totalLessons,
  });

  factory InProgressCourse.fromJson(Map<String, dynamic> j) => InProgressCourse(
        id:               j['id']                as int?    ?? 0,
        title:            j['title']             as String? ?? '',
        thumbnail:        j['thumbnail']         as String? ?? '',
        completedPercent: j['completed_percent'] as int?    ?? 0,
        completedLessons: j['completed_lessons'] as int?    ?? 0,
        totalLessons:     j['total_lessons']     as int?    ?? 0,
      );
}

class DashboardStats {
  final int enrolledCount;
  final int activeCount;
  final int completedCount;
  final List<InProgressCourse> inProgress;

  const DashboardStats({
    this.enrolledCount  = 0,
    this.activeCount    = 0,
    this.completedCount = 0,
    this.inProgress     = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        enrolledCount:  j['enrolled_count']  as int? ?? 0,
        activeCount:    j['active_count']     as int? ?? 0,
        completedCount: j['completed_count']  as int? ?? 0,
        inProgress: (j['in_progress'] as List? ?? [])
            .map((e) => InProgressCourse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Dashboard Provider ────────────────────────────────────────────────────────
// FIX: يستخدم authProvider مباشرة بدل currentUserIdProvider لضمان أن
// FutureProvider لا يُنفَّذ أبداً أثناء AuthInitial أو AuthLoading.
// كان يُنفَّذ بـ userId=0 ويُخزَّن كـ error ولا يُعاد تنفيذه.

final dashboardProvider = FutureProvider<DashboardStats>((ref) async {
  final authState = ref.watch(authProvider);

  // لا تُنفَّذ الـ request حتى تكتمل المصادقة
  if (authState is! AuthAuthenticated) {
    throw Exception('يرجى تسجيل الدخول أولاً');
  }

  try {
    final res = await DioClient.instance.dio
        .get(ApiConstants.dashboardEndpoint);
    final body = res.data as Map<String, dynamic>?;
    final data = (body?['data'] as Map<String, dynamic>?) ?? {};
    return DashboardStats.fromJson(data);
  } on DioException catch (e) {
    final body = e.response?.data;
    String? msg;
    if (body is Map) msg = body['message'] as String?;
    throw Exception(msg ?? dioErrorMessage(e));
  }
});

// ── My Courses Filter ─────────────────────────────────────────────────────────

class MyCoursesFilter {
  final String status; // 'all' | 'active' | 'completed'
  final int page;
  const MyCoursesFilter({this.status = 'all', this.page = 1});

  @override
  bool operator ==(Object other) =>
      other is MyCoursesFilter && status == other.status && page == other.page;

  @override
  int get hashCode => Object.hash(status, page);
}

// ── My Course Item ────────────────────────────────────────────────────────────

class MyCourseItem {
  final Course course;
  final int completedPercent;
  final int completedLessons;
  final bool isCourseCompleted;

  const MyCourseItem({
    required this.course,
    required this.completedPercent,
    required this.completedLessons,
    required this.isCourseCompleted,
  });
}

// ── My Courses Provider ───────────────────────────────────────────────────────
// FIX: نفس الإصلاح — يراقب authProvider مباشرة

final myCoursesProvider =
    FutureProvider.family<CoursePage, MyCoursesFilter>((ref, filter) async {
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) {
    throw Exception('يرجى تسجيل الدخول أولاً');
  }

  try {
    final res = await DioClient.instance.dio.get(
      ApiConstants.myCoursesEndpoint,
      queryParameters: {'status': filter.status, 'page': filter.page},
    );
    final body = res.data as Map<String, dynamic>?;
    if (body == null) return CoursePage.empty;

    final list = body['data'] as List? ?? [];
    return CoursePage(
      courses:     list.map((e) => _parseMyCourse(e as Map<String, dynamic>)).toList(),
      total:       body['total']       as int? ?? 0,
      totalPages:  body['total_pages'] as int? ?? 1,
      currentPage: body['page']        as int? ?? filter.page,
    );
  } on DioException catch (e) {
    final body = e.response?.data;
    String? msg;
    if (body is Map) msg = body['message'] as String?;
    throw Exception(msg ?? dioErrorMessage(e));
  }
});

final myCourseItemsProvider =
    FutureProvider.family<List<MyCourseItem>, MyCoursesFilter>((ref, filter) async {
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) {
    throw Exception('يرجى تسجيل الدخول أولاً');
  }

  try {
    final res = await DioClient.instance.dio.get(
      ApiConstants.myCoursesEndpoint,
      queryParameters: {'status': filter.status, 'page': filter.page},
    );
    final body = res.data as Map<String, dynamic>?;
    if (body == null) return [];
    final list = body['data'] as List? ?? [];
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return MyCourseItem(
        course:            _parseMyCourse(m),
        completedPercent:  m['completed_percent']   as int?  ?? 0,
        completedLessons:  m['completed_lessons']   as int?  ?? 0,
        isCourseCompleted: m['is_course_completed'] as bool? ?? false,
      );
    }).toList();
  } on DioException catch (e) {
    final body = e.response?.data;
    String? msg;
    if (body is Map) msg = body['message'] as String?;
    throw Exception(msg ?? dioErrorMessage(e));
  }
});

Course _parseMyCourse(Map<String, dynamic> m) => Course(
      id:               m['id']             as int?    ?? 0,
      title:            m['title']          as String? ?? '',
      description:      m['content']        as String? ?? '',
      thumbnail:        m['thumbnail']      as String? ?? '',
      instructorName:   m['author']         as String? ?? '',
      instructorAvatar: m['author_avatar']  as String? ?? '',
      instructorId:     m['author_id']      as int?    ?? 0,
      totalLessons:     m['total_lessons']  as int?    ?? 0,
      totalEnrolled:    m['total_enrolled'] as int?    ?? 0,
      rating:           (m['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount:      m['rating_count']   as int?    ?? 0,
      isEnrolled:       true,
      price:            m['price']          as String? ?? '',
      isFree:           m['is_free']        as bool?   ?? true,
      permalink:        m['link']           as String? ?? '',
    );
