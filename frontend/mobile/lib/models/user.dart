class User {
  final String id;
  final String email;
  final String username;
  final String? fullName;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.fullName,
    this.phone,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        email: json['email'],
        username: json['username'],
        fullName: json['full_name'],
        phone: json['phone'],
        isActive: json['is_active'],
        createdAt: DateTime.parse(json['created_at']),
      );

  String get displayName => fullName ?? username;
}
