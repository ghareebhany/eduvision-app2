import 'package:equatable/equatable.dart';

class Topic extends Equatable {
  final int id;
  final String title;
  final int courseId;
  final int order;
  final List<Lesson> lessons;

  const Topic({
    required this.id,
    required this.title,
    required this.courseId,
    required this.order,
    required this.lessons,
  });

  @override
  List<Object?> get props => [id, title, lessons];
}

class Lesson extends Equatable {
  final int id;
  final String title;
  final int topicId;
  final int courseId;
  final int order;
  final String type;
  final String videoUrl;
  final String videoSource;   // 'youtube'|'vimeo'|'html5'|'external_url'|'embedded'|'shortcode'|''
  final String videoDuration;
  final bool isCompleted;
  final String content;
  final String lessonUrl;     // رابط صفحة الدرس الحقيقية على الموقع

  // 🔥 خاصية videoType للتحقق السريع (مشتقة من videoSource)
  String get videoType => videoSource;

  const Lesson({
    required this.id,
    required this.title,
    required this.topicId,
    required this.courseId,
    required this.order,
    required this.type,
    required this.videoUrl,
    required this.videoSource,
    required this.videoDuration,
    required this.isCompleted,
    required this.content,
    this.lessonUrl = '',
  });

  bool get hasVideo    => videoUrl.isNotEmpty;
  bool get isQuiz      => type == 'quiz';
  bool get isAssignment=> type == 'assignment';
  bool get isVideo     => type == 'video' || (type == 'lesson' && videoUrl.isNotEmpty);
  bool get isTextOnly  => !hasVideo && !isQuiz && !isAssignment;
  
  // 🔥 خصائص مساعدة للتحقق من نوع الفيديو
  bool get isYoutube => videoSource == 'youtube' || 
                         (videoUrl.isNotEmpty && 
                          (videoUrl.contains('youtube.com') || 
                           videoUrl.contains('youtu.be')));
  
  bool get isVimeo => videoSource == 'vimeo' || 
                       (videoUrl.isNotEmpty && videoUrl.contains('vimeo.com'));

  @override
  List<Object?> get props => [id, isCompleted];
}