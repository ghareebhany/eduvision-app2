import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.displayName,
    required super.avatarUrl,
    required super.token,
    super.bio = '',
    super.website = '',
    super.phone = '',
  });

  /// From JWT /token endpoint
  /// Response: {token, user_email, user_nicename, user_display_name, user_id}
  factory UserModel.fromLoginJson(Map<String, dynamic> json) {
    // user_id may come as int or String
    final rawId = json['user_id'];
    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    return UserModel(
      id: id,
      email: json['user_email'] as String? ?? '',
      displayName: json['user_display_name'] as String? ??
          json['user_nicename'] as String? ??
          '',
      avatarUrl: '',
      token: json['token'] as String? ?? '',
    );
  }

  /// From /tutor/v1/profile/{id}
  factory UserModel.fromProfileJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return UserModel(
      id: _parseInt(data['ID'] ?? data['id']),
      email: data['user_email'] as String? ?? '',
      displayName: data['display_name'] as String? ??
          data['name'] as String? ??
          '',
      avatarUrl: data['avatar_url'] as String? ??
          data['profile_photo_url'] as String? ??
          '',
      token: '',
      bio: data['description'] as String? ?? data['bio'] as String? ?? '',
      website: data['user_url'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        'display_name': displayName,
        'description': bio,
        'user_url': website,
        'phone': phone,
      };

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
