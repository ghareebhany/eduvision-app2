import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/review.dart';
import '../entities/user.dart';

abstract class IProfileRepository {
  Future<Either<Failure, User>> getProfile(int userId);
  Future<Either<Failure, bool>> updateProfile(Map<String, dynamic> data);
  Future<Either<Failure, User>> getInstructorInfo(int instructorId);
  Future<Either<Failure, List<Review>>> getReviews({int? courseId, int page});
}
