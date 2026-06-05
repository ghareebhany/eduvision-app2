import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int id;
  final String email;
  final String displayName;
  final String avatarUrl;
  final String token;
  final String bio;
  final String website;
  final String phone;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.token,
    this.bio = '',
    this.website = '',
    this.phone = '',
  });

  @override
  List<Object?> get props => [id, email];
}
