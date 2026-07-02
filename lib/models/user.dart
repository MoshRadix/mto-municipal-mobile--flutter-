class User {
  final String id;
  final String email;
  final String? username;
  final String name;
  final String role; // "entry", "read-only", "admin", "superadmin"

  User({
    required this.id,
    required this.email,
    this.username,
    required this.name,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'name': name,
      'role': role,
    };
  }

  bool get isAdmin => role == 'admin' || role == 'superadmin';
  bool get isEntry => role == 'entry';
  bool get isReadOnly => role == 'read-only';
}
