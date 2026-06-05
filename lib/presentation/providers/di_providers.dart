import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repo_impl.dart';
import '../../data/repositories/course_repo_impl.dart';
import '../../data/repositories/profile_repo_impl.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_course_repository.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../../domain/usecases/usecases.dart';

// ── Repositories ──────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<IAuthRepository>(
  (_) => AuthRepositoryImpl(),
);

final courseRepositoryProvider = Provider<ICourseRepository>(
  (_) => CourseRepositoryImpl(),
);

final profileRepositoryProvider = Provider<IProfileRepository>(
  (_) => ProfileRepositoryImpl(),
);

// ── Use cases ─────────────────────────────────────────────────────────────────

final loginUseCaseProvider = Provider(
  (ref) => LoginUseCase(ref.read(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider(
  (ref) => LogoutUseCase(ref.read(authRepositoryProvider)),
);

final getCoursesUseCaseProvider = Provider(
  (ref) => GetCoursesUseCase(ref.read(courseRepositoryProvider)),
);

final getCourseDetailUseCaseProvider = Provider(
  (ref) => GetCourseDetailUseCase(ref.read(courseRepositoryProvider)),
);

final getTopicsUseCaseProvider = Provider(
  (ref) => GetTopicsUseCase(ref.read(courseRepositoryProvider)),
);

final getLessonsUseCaseProvider = Provider(
  (ref) => GetLessonsUseCase(ref.read(courseRepositoryProvider)),
);

final markLessonCompleteUseCaseProvider = Provider(
  (ref) => MarkLessonCompleteUseCase(ref.read(courseRepositoryProvider)),
);

final markCourseCompleteUseCaseProvider = Provider(
  (ref) => MarkCourseCompleteUseCase(ref.read(courseRepositoryProvider)),
);

final enrollCourseUseCaseProvider = Provider(
  (ref) => EnrollCourseUseCase(ref.read(courseRepositoryProvider)),
);

final getProfileUseCaseProvider = Provider(
  (ref) => GetProfileUseCase(ref.read(profileRepositoryProvider)),
);

final updateProfileUseCaseProvider = Provider(
  (ref) => UpdateProfileUseCase(ref.read(profileRepositoryProvider)),
);

final getInstructorInfoUseCaseProvider = Provider(
  (ref) => GetInstructorInfoUseCase(ref.read(profileRepositoryProvider)),
);

final getReviewsUseCaseProvider = Provider(
  (ref) => GetReviewsUseCase(ref.read(profileRepositoryProvider)),
);
