import '../constants/app_constants.dart';

class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;

  _CacheEntry(this.data, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// In-memory cache with TTL and user-scoped key support.
/// No disk persistence — clears on app restart.
class CacheManager {
  CacheManager._();
  static final CacheManager instance = CacheManager._();

  final Map<String, _CacheEntry<dynamic>> _store = {};

  // Fix #3: Build user-scoped keys automatically
  String _scopedKey(String key) {
    final uid = _currentUserId;
    return uid > 0 ? 'u${uid}_$key' : key;
  }

  int _currentUserId = 0;

  /// Call after login / on startup
  void setCurrentUser(int userId) {
    _currentUserId = userId;
  }

  void clearCurrentUser() {
    _currentUserId = 0;
  }

  void set<T>(String key, T value, {Duration? ttl, bool userScoped = true}) {
    final k = userScoped ? _scopedKey(key) : key;
    _store[k] = _CacheEntry<T>(
      value,
      DateTime.now().add(ttl ?? AppConstants.cacheTtl),
    );
  }

  T? get<T>(String key, {bool userScoped = true}) {
    final k = userScoped ? _scopedKey(key) : key;
    final entry = _store[k];
    if (entry == null || entry.isExpired) {
      _store.remove(k);
      return null;
    }
    return entry.data as T?;
  }

  void invalidate(String key, {bool userScoped = true}) {
    final k = userScoped ? _scopedKey(key) : key;
    _store.remove(k);
  }

  /// Fix: invalidate both lessons_ AND topics_ on completion
  void invalidatePattern(String prefix, {bool userScoped = true}) {
    final scopedPrefix = userScoped && _currentUserId > 0
        ? 'u${_currentUserId}_$prefix'
        : prefix;
    _store.removeWhere((k, _) => k.startsWith(scopedPrefix));
  }

  /// Invalidate all course-related entries for current user
  void invalidateCourseData() {
    invalidatePattern('courses_');
    invalidatePattern('topics_');   // Fix: also topics
    invalidatePattern('lessons_');  // Fix: also lessons
  }

  void clear() => _store.clear();

  /// Clear only the current user's cache (on logout)
  void clearUserCache() {
    if (_currentUserId > 0) {
      _store.removeWhere((k, _) => k.startsWith('u${_currentUserId}_'));
    }
    _currentUserId = 0;
  }
}
