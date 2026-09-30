/// Bốn vai trò người dùng của hệ thống.
enum UserRole {
  staff('Cán bộ quản lý đào tạo'),
  head('Trưởng bộ môn'),
  lecturer('Giảng viên'),
  student('Sinh viên');

  const UserRole(this.label);

  final String label;

  static UserRole parse(String value) =>
      UserRole.values.firstWhere((r) => r.name == value);
}

/// Hồ sơ người dùng, document `users/{uid}`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.role,
    required this.fullName,
    required this.code,
    required this.email,
    this.department = '',
  });

  final String uid;
  final UserRole role;
  final String fullName;

  /// Mã sinh viên (HE170001) hoặc tài khoản giảng viên (sonnt5).
  final String code;
  final String email;

  /// Bộ môn: dùng cho giảng viên và trưởng bộ môn (VD `SE`, `AI`).
  final String department;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
    uid: uid,
    role: UserRole.parse(map['role'] as String),
    fullName: map['fullName'] as String,
    code: map['code'] as String,
    email: map['email'] as String,
    department: map['department'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'role': role.name,
    'fullName': fullName,
    'code': code,
    'email': email,
    'department': department,
  };
}
