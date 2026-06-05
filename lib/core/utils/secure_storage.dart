import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Token ────────────────────────────────────────────────────────────────
  Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.tokenKey, value: token);

  Future<String?> getToken() =>
      _storage.read(key: AppConstants.tokenKey);

  Future<void> deleteToken() =>
      _storage.delete(key: AppConstants.tokenKey);

  // ── Nonce (persisted — survives app restart) ─────────────────────────────
  // Tutor LMS Pro /students/{id}/dashboard + /courses require
  // X-WP-Nonce alongside JWT Bearer. Must survive app restarts.
  Future<void> saveNonce(String nonce) =>
      _storage.write(key: AppConstants.nonceKey, value: nonce);

  Future<String?> getNonce() =>
      _storage.read(key: AppConstants.nonceKey);

  Future<void> deleteNonce() =>
      _storage.delete(key: AppConstants.nonceKey);

  // ── User meta ────────────────────────────────────────────────────────────
  Future<void> saveUserId(int id) =>
      _storage.write(key: AppConstants.userIdKey, value: id.toString());

  Future<int?> getUserId() async {
    final raw = await _storage.read(key: AppConstants.userIdKey);
    return raw != null ? int.tryParse(raw) : null;
  }

  Future<void> saveUserEmail(String email) =>
      _storage.write(key: AppConstants.userEmailKey, value: email);

  Future<String?> getUserEmail() =>
      _storage.read(key: AppConstants.userEmailKey);

  Future<void> saveDisplayName(String name) =>
      _storage.write(key: AppConstants.userDisplayNameKey, value: name);

  Future<String?> getDisplayName() =>
      _storage.read(key: AppConstants.userDisplayNameKey);

  // ── Clear all ────────────────────────────────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();

  // ── Auth state ───────────────────────────────────────────────────────────
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
