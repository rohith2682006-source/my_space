class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final bool isVerified;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.isVerified = false,
    this.role = 'USER',
  });

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      avatarUrl: json['avatarUrl'],
      isVerified: json['isVerified'] ?? false,
      role: json['role'] ?? 'USER',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
      'role': role,
    };
  }
}

