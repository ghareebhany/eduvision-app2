import '../../domain/entities/lesson.dart';

class TopicModel extends Topic {
  const TopicModel({
    required super.id,
    required super.title,
    required super.courseId,
    required super.order,
    required super.lessons,
  });

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['lessons'] as List<dynamic>? ?? [];
    return TopicModel(
      id:       _parseInt(json['id']),
      title:    _strip(json['title'] as String? ?? ''),
      courseId: _parseInt(json['course_id']),
      order:    _parseInt(json['order'] ?? json['menu_order']),
      lessons:  rawLessons
          .map((l) => LessonModel.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  static String _strip(String h) => h.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}

class LessonModel extends Lesson {
  const LessonModel({
    required super.id,
    required super.title,
    required super.topicId,
    required super.courseId,
    required super.order,
    required super.type,
    required super.videoUrl,
    required super.videoSource,
    required super.videoDuration,
    required super.isCompleted,
    required super.content,
    super.lessonUrl = '',
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id:            _parseInt(json['id']),
      title:         _strip(json['title'] as String? ?? ''),
      topicId:       _parseInt(json['topic_id'] ?? json['parent']),
      courseId:      _parseInt(json['course_id']),
      order:         _parseInt(json['order'] ?? json['menu_order']),
      type:          json['type']        as String? ?? 'lesson',
      videoUrl:      json['video_url']   as String? ?? '',
      videoSource:   json['video_source'] as String? ?? '',
      videoDuration: json['video_duration'] as String? ?? '',
      isCompleted:   json['is_completed'] == true || json['is_completed'] == 1,
      content:       _strip(json['content'] as String? ?? ''),
      lessonUrl:     json['lesson_url']  as String? ?? '',
    );
  }

  LessonModel copyWithCompleted(bool completed) => LessonModel(
        id: id, title: title, topicId: topicId, courseId: courseId,
        order: order, type: type, videoUrl: videoUrl,
        videoSource: videoSource, videoDuration: videoDuration,
        isCompleted: completed, content: content, lessonUrl: lessonUrl,
      );

  static String _strip(String h) => h.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
