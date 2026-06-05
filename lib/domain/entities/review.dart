import 'package:equatable/equatable.dart';

class Review extends Equatable {
  final int id;
  final int courseId;
  final String authorName;
  final String authorAvatar;
  final double rating;
  final String content;
  final String date;

  const Review({
    required this.id,
    required this.courseId,
    required this.authorName,
    required this.authorAvatar,
    required this.rating,
    required this.content,
    required this.date,
  });

  @override
  List<Object?> get props => [id];
}
