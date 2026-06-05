import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class VideoProgressService {
  VideoProgressService._();
  static final VideoProgressService instance = VideoProgressService._();

  /// Save playback position in seconds for a given lessonId
  Future<void> savePosition(int lessonId, int positionSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        '${AppConstants.videoProgressPrefix}$lessonId', positionSeconds);
  }

  /// Get saved position; returns 0 if none stored
  Future<int> getPosition(int lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(
            '${AppConstants.videoProgressPrefix}$lessonId') ?? 0;
  }

  /// Clear position once lesson is completed
  Future<void> clearPosition(int lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${AppConstants.videoProgressPrefix}$lessonId');
  }
}
