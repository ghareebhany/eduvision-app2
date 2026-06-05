import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final int id;
  final String title;
  final String description;
  final String thumbnail;
  final String instructorName;
  final String instructorAvatar;
  final int instructorId;
  final int totalLessons;
  final int totalEnrolled;
  final double rating;
  final int ratingCount;
  final bool isEnrolled;
  final String price;
  final bool isFree;
  final String permalink;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.instructorName,
    required this.instructorAvatar,
    required this.instructorId,
    required this.totalLessons,
    required this.totalEnrolled,
    required this.rating,
    required this.ratingCount,
    required this.isEnrolled,
    required this.price,
    required this.isFree,
    required this.permalink,
  });

  Course copyWith({
    int? id,
    String? title,
    String? description,
    String? thumbnail,
    String? instructorName,
    String? instructorAvatar,
    int? instructorId,
    int? totalLessons,
    int? totalEnrolled,
    double? rating,
    int? ratingCount,
    bool? isEnrolled,
    String? price,
    bool? isFree,
    String? permalink,
  }) =>
      Course(
        id:               id               ?? this.id,
        title:            title            ?? this.title,
        description:      description      ?? this.description,
        thumbnail:        thumbnail        ?? this.thumbnail,
        instructorName:   instructorName   ?? this.instructorName,
        instructorAvatar: instructorAvatar ?? this.instructorAvatar,
        instructorId:     instructorId     ?? this.instructorId,
        totalLessons:     totalLessons     ?? this.totalLessons,
        totalEnrolled:    totalEnrolled    ?? this.totalEnrolled,
        rating:           rating           ?? this.rating,
        ratingCount:      ratingCount      ?? this.ratingCount,
        isEnrolled:       isEnrolled       ?? this.isEnrolled,
        price:            price            ?? this.price,
        isFree:           isFree           ?? this.isFree,
        permalink:        permalink        ?? this.permalink,
      );

  @override
  List<Object?> get props => [id, title, isEnrolled];
}
