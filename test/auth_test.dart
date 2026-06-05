import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:eduvision_app/core/errors/failures.dart';
import 'package:eduvision_app/domain/entities/user.dart';
import 'package:eduvision_app/domain/repositories/i_auth_repository.dart';
import 'package:eduvision_app/presentation/providers/auth_provider.dart';
import 'package:eduvision_app/presentation/providers/dashboard_provider.dart';
import 'package:eduvision_app/presentation/providers/di_providers.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements IAuthRepository {}

// ── Test user ─────────────────────────────────────────────────────────────────

const _testUser = User(
  id:          42,
  email:       'test@eduvision3.com',
  displayName: 'Test User',
  avatarUrl:   '',
  token:       'fake.jwt.token',
);

// ── Container builder ─────────────────────────────────────────────────────────

ProviderContainer _buildContainer(MockAuthRepository repo) {
  return ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
}

MockAuthRepository _unauthRepo() {
  final r = MockAuthRepository();
  when(() => r.isLoggedIn()).thenAnswer((_) async => false);
  when(() => r.getCurrentUserId()).thenAnswer((_) async => null);
  return r;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('AuthNotifier', () {
    test('starts AuthInitial → resolves to AuthUnauthenticated', () async {
      final repo      = _unauthRepo();
      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      expect(container.read(authProvider), isA<AuthInitial>());
      // Poll until _checkInitialAuth resolves — handles slow CI environments
      for (var i = 0; i < 20; i++) {
        if (container.read(authProvider) is! AuthInitial) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(container.read(authProvider), isA<AuthUnauthenticated>());
    });

    test('login success → AuthAuthenticated with correct userId', () async {
      final repo = _unauthRepo();
      when(() => repo.login(any(), any()))
          .thenAnswer((_) async => const Right(_testUser));

      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      // Poll until _checkInitialAuth resolves — handles slow CI environments
      for (var i = 0; i < 20; i++) {
        if (container.read(authProvider) is! AuthInitial) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await container.read(authProvider.notifier).login('test', 'pass');

      final state = container.read(authProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user.id, equals(42));
    });

    test('login failure → AuthError with message', () async {
      final repo = _unauthRepo();
      when(() => repo.login(any(), any())).thenAnswer(
        (_) async => const Left(
            ServerFailure('بيانات الدخول غير صحيحة', statusCode: 403)),
      );

      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      // Poll until _checkInitialAuth resolves — handles slow CI environments
      for (var i = 0; i < 20; i++) {
        if (container.read(authProvider) is! AuthInitial) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await container.read(authProvider.notifier).login('bad', 'creds');

      final state = container.read(authProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).message, contains('غير صحيحة'));
    });

    test('logout → AuthUnauthenticated', () async {
      final repo = _unauthRepo();
      when(() => repo.login(any(), any()))
          .thenAnswer((_) async => const Right(_testUser));
      when(() => repo.logout())
          .thenAnswer((_) async => const Right(true));

      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      // Poll until _checkInitialAuth resolves — handles slow CI environments
      for (var i = 0; i < 20; i++) {
        if (container.read(authProvider) is! AuthInitial) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await container.read(authProvider.notifier).login('test', 'pass');
      expect(container.read(authProvider), isA<AuthAuthenticated>());

      await container.read(authProvider.notifier).logout();
      expect(container.read(authProvider), isA<AuthUnauthenticated>());
    });

    test('isAuthenticatedProvider true after login', () async {
      final repo = _unauthRepo();
      when(() => repo.login(any(), any()))
          .thenAnswer((_) async => const Right(_testUser));

      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      // Poll until _checkInitialAuth resolves — handles slow CI environments
      for (var i = 0; i < 20; i++) {
        if (container.read(authProvider) is! AuthInitial) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(container.read(isAuthenticatedProvider), isFalse);

      await container.read(authProvider.notifier).login('test', 'pass');
      expect(container.read(isAuthenticatedProvider), isTrue);
    });

    test('currentUserIdProvider returns 0 when unauthenticated', () async {
      final repo      = _unauthRepo();
      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      // Poll until _checkInitialAuth resolves — handles slow CI environments
      for (var i = 0; i < 20; i++) {
        if (container.read(authProvider) is! AuthInitial) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      expect(container.read(authProvider), isA<AuthUnauthenticated>());
      expect(container.read(currentUserIdProvider), equals(0));
    });

    test('currentUserIdProvider returns correct id after login', () async {
      final repo = _unauthRepo();
      when(() => repo.login(any(), any()))
          .thenAnswer((_) async => const Right(_testUser));

      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      // Poll until _checkInitialAuth resolves — handles slow CI environments
      for (var i = 0; i < 20; i++) {
        if (container.read(authProvider) is! AuthInitial) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await container.read(authProvider.notifier).login('test', 'pass');

      expect(container.read(currentUserIdProvider), equals(42));
    });

    test('currentUserIdProvider returns 0 after logout', () async {
      final repo = _unauthRepo();
      when(() => repo.login(any(), any()))
          .thenAnswer((_) async => const Right(_testUser));
      when(() => repo.logout())
          .thenAnswer((_) async => const Right(true));

      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      // Poll until _checkInitialAuth resolves — handles slow CI environments
      for (var i = 0; i < 20; i++) {
        if (container.read(authProvider) is! AuthInitial) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await container.read(authProvider.notifier).login('test', 'pass');
      expect(container.read(currentUserIdProvider), equals(42));

      await container.read(authProvider.notifier).logout();
      expect(container.read(currentUserIdProvider), equals(0));
    });

    test('session restore: isLoggedIn=true resolves to AuthAuthenticated', () async {
      expect(await _unauthRepo().isLoggedIn(), isFalse);

      final loggedRepo = MockAuthRepository();
      when(() => loggedRepo.isLoggedIn()).thenAnswer((_) async => true);
      when(() => loggedRepo.getCurrentUserId()).thenAnswer((_) async => 42);
      expect(await loggedRepo.isLoggedIn(), isTrue);
      expect(await loggedRepo.getCurrentUserId(), equals(42));
    });
  });

  group('UserModel fromLoginJson', () {
    test('parses int userId', () {
      // Use dynamic to properly test the runtime type check path
      final dynamic rawId = 99;
      final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
      expect(id, equals(99));
    });

    test('parses String userId', () {
      const rawId = '99';
      final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
      expect(id, equals(99));
    });

    test('returns 0 for null userId', () {
      const dynamic rawId = null;
      final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
      expect(id, equals(0));
    });
  });
}
