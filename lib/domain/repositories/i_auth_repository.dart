// i_auth_repository.dart
import 'package:dartz/dartz.dart';
import '../entities/user.dart';
import '../../core/errors/failures.dart';

abstract class IAuthRepository {
  Future<Either<Failure, User>> login(String username, String password);
  Future<Either<Failure, bool>> logout();
  Future<bool> isLoggedIn();
  Future<int?> getCurrentUserId();
}
