import '../../domain/entities/review.dart';

class ReviewModel extends Review {
  const ReviewModel({
    required super.id,
    required super.courseId,
    required super.authorName,
    required super.authorAvatar,
    required super.rating,
    required super.content,
    required super.date,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? {};
    return ReviewModel(
      id: json['id'] as int? ?? 0,
      courseId: json['course_id'] as int? ?? 0,
      authorName: author['display_name'] as String? ?? '',
      authorAvatar: author['avatar_url'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      content: json['comment'] as String? ?? json['content'] as String? ?? '',
      date: json['date'] as String? ?? '',
    );
  }
}
