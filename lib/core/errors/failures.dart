import 'package:equatable/equatable.dart';

/// Base failure – never throw, always return via Either<Failure, T>
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

/// 401 – expired / missing token
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً']);
}

/// 403 – user not enrolled in this course (paid content gate)
class EnrollmentFailure extends Failure {
  final int courseId;
  // FIX: named super constructor parameter غير مدعوم مع required params — نستخدم initializer list
  const EnrollmentFailure({
    this.courseId = 0,
    String message = 'يجب التسجيل في هذا الكورس أولاً للوصول إلى المحتوى',
  }) : super(message);

  @override
  List<Object> get props => [message, courseId];
}

/// Network unreachable
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'لا يوجد اتصال بالإنترنت']);
}

/// Server returned 4xx/5xx
class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});

  @override
  List<Object> get props => [message, statusCode ?? 0];
}

/// Empty / null response body
class EmptyResponseFailure extends Failure {
  const EmptyResponseFailure([super.message = 'لا توجد بيانات']);
}

/// Generic catch-all
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'حدث خطأ غير متوقع']);
}
