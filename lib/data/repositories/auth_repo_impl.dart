import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/auth_remote_ds.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final AuthRemoteDataSource _remote;
  final SecureStorageService _storage;

  AuthRepositoryImpl({
    AuthRemoteDataSource? remote,
    SecureStorageService? storage,
  })  : _remote = remote ?? AuthRemoteDataSource.instance,
        _storage = storage ?? SecureStorageService.instance;

  @override
  Future<Either<Failure, User>> login(
      String username, String password) async {
    try {
      final model = await _remote.login(username, password);

      await Future.wait([
        _storage.saveToken(model.token),
        _storage.saveUserId(model.id),
        _storage.saveUserEmail(model.email),
        _storage.saveDisplayName(model.displayName),
      ]);

      CacheManager.instance.setCurrentUser(model.id);

      // Fetch nonce and persist — required for Tutor LMS Pro student endpoints
      // We don't await this to prevent login hang if nonce endpoint is slow/failing
      _remote.fetchNonce();

      return Right<Failure, User>(model);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> logout() async {
    try {
      DioClient.instance.clearNonce();
      CacheManager.instance.clearUserCache();
      await _storage.clearAll();
      return const Right(true);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<bool> isLoggedIn() => _storage.isLoggedIn();

  @override
  Future<int?> getCurrentUserId() => _storage.getUserId();
}
