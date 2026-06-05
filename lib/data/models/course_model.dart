import '../../domain/entities/course.dart';

class CourseModel extends Course {
  const CourseModel({
    required super.id,
    required super.title,
    required super.description,
    required super.thumbnail,
    required super.instructorName,
    required super.instructorAvatar,
    required super.instructorId,
    required super.totalLessons,
    required super.totalEnrolled,
    required super.rating,
    required super.ratingCount,
    required super.isEnrolled,
    required super.price,
    required super.isFree,
    required super.permalink,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    final priceRaw = json['price'] as String? ?? '';

    // Fix 3: اقرأ is_free من الـ server أولاً — PHP يُرسله بشكل صحيح
    // fallback للحساب المحلي فقط إذا غاب الحقل
    final bool isFree = json.containsKey('is_free')
        ? (json['is_free'] == true || json['is_free'] == 1)
        : (priceRaw.isEmpty || priceRaw == '0' || priceRaw == 'free');

    return CourseModel(
      id:              _parseInt(json['id']),
      title:           _stripHtml(json['title'] as String? ?? ''),
      description:     _stripHtml(json['content'] as String? ?? ''),
      thumbnail:       json['thumbnail'] as String? ?? '',
      instructorName:  json['author'] as String? ?? '',
      // Fix 4: اقرأ author_avatar — كان hardcoded ''
      instructorAvatar: json['author_avatar'] as String? ?? '',
      instructorId:    _parseInt(json['author_id']),
      totalLessons:    _parseInt(json['total_lessons']),
      totalEnrolled:   _parseInt(json['total_enrolled']),
      rating:          _parseDouble(json['rating']),
      ratingCount:     _parseInt(json['rating_count']),
      isEnrolled:      json['is_enrolled'] == true || json['is_enrolled'] == 1,
      price:           priceRaw,
      isFree:          isFree,
      permalink:       json['link'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id':              id,
        'title':           title,
        'description':     description,
        'thumbnail':       thumbnail,
        'instructor_name': instructorName,
        'instructor_id':   instructorId,
      };

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
