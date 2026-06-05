/// RemoteDataSource – Façade
///
/// تم تقسيم المنطق إلى 4 datasources متخصصة:
///   • AuthRemoteDataSource    ← auth_remote_ds.dart
///   • CoursesRemoteDataSource ← courses_remote_ds.dart
///   • LessonsRemoteDataSource ← lessons_remote_ds.dart
///   • ProfileRemoteDataSource ← profile_remote_ds.dart
///
/// هذا الملف يبقى كـ backward-compatible façade.
/// الـ repositories تستورد الـ datasources مباشرة.

export 'auth_remote_ds.dart';
export 'courses_remote_ds.dart';
export 'lessons_remote_ds.dart';
export 'profile_remote_ds.dart';
