import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/bundle_detail_screen.dart';
import '../screens/course_detail_screen.dart';
import '../screens/courses_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/instructor_screen.dart';
import '../screens/lesson_list_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/my_courses_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/redeem_code_screen.dart';
import '../screens/register_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/lesson_web_screen.dart';

// ✅ التغيير الوحيد في الـ imports:
// ❌ حذف: import '../lesson/webview_lesson_screen.dart';
// ✅ إضافة:
import '../lesson/native_lesson_screen.dart';

import '../../domain/entities/lesson.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final path      = state.uri.path;

      if (authState is AuthInitial || authState is AuthLoading) {
        return path == '/' ? null : '/';
      }

      final isAuth = authState is AuthAuthenticated;

      const publicRoutes = ['/', '/login', '/register'];
      if (!isAuth && !publicRoutes.contains(path)) return '/login';
      if (isAuth && (path == '/login' || path == '/register' || path == '/')) {
        return '/home';
      }
      return null;
    },
    refreshListenable: _AuthStateListenable(ref),
    routes: [
      // ── Public ───────────────────────────────────────────────────
      GoRoute(path: '/',         builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // ── Main Shell (Bottom Navigation) ───────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home',       builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/courses',    builder: (_, __) => const CoursesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/my-courses', builder: (_, __) => const MyCoursesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile',    builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),

      // ── Bundle Detail ─────────────────────────────────────────────
      GoRoute(
        path: '/bundle/:id',
        builder: (_, state) => BundleDetailScreen(
          bundleId: int.parse(state.pathParameters['id']!),
        ),
      ),

      // ── Redeem Code ───────────────────────────────────────────────
      GoRoute(
        path: '/redeem-code',
        builder: (_, state) => RedeemCodeScreen(
          params: state.extra as Map<String, dynamic>?,
        ),
      ),

      // ── Course Detail ─────────────────────────────────────────────
      GoRoute(
        path: '/course/:id',
        builder: (_, state) => CourseDetailScreen(
          courseId: int.parse(state.pathParameters['id']!),
        ),
      ),

      // ── Lessons ───────────────────────────────────────────────────
      GoRoute(
        path: '/lessons/:courseId',
        builder: (_, state) => LessonListScreen(
          courseId: int.parse(state.pathParameters['courseId']!),
        ),
      ),

      // ── Video Player ──────────────────────────────────────────────
      // ✅ التغيير الجوهري: WebViewLessonScreen → NativeLessonScreen
      // باقي الكود (path, extra) لم يتغير — lesson_list_screen يعمل بدون تعديل
      GoRoute(
        path: '/video/:lessonId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return NativeLessonScreen(                    // ← التغيير هنا فقط
            lesson:     extra['lesson']     as Lesson,
            courseId:   extra['courseId']   as int,
            allLessons: extra['allLessons'] as List<Lesson>,
          );
        },
      ),

      GoRoute(
        path: '/lesson-web/:id',
        builder: (_, state) => LessonWebScreen(
          lessonId: int.parse(state.pathParameters['id']!),
          title: (state.extra as Map?)?['title'] as String? ?? 'الدرس',
        ),
      ),

      // ── Quiz ──────────────────────────────────────────────────────
      GoRoute(
        path: '/quiz/:id',
        builder: (_, state) => QuizScreen(
          quizId: int.parse(state.pathParameters['id']!),
        ),
      ),

      // ── Instructor ────────────────────────────────────────────────
      GoRoute(
        path: '/instructor/:id',
        builder: (_, state) => InstructorScreen(
          instructorId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('الصفحة غير موجودة: ${state.error}')),
    ),
  );
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}
