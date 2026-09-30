import 'app_user.dart';

/// Đối tượng nhận thông báo.
enum Audience {
  all('Tất cả'),
  students('Sinh viên'),
  lecturers('Giảng viên');

  const Audience(this.label);

  final String label;

  bool includes(UserRole role) => switch (this) {
    Audience.all => true,
    Audience.students => role == UserRole.student,
    Audience.lecturers => role == UserRole.lecturer || role == UserRole.head,
  };
}

/// Thông báo do cán bộ đào tạo đăng, document `notifications/{id}`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.content,
    required this.audience,
    required this.createdAt,
    required this.authorName,
  });

  final String id;
  final String title;
  final String content;
  final Audience audience;
  final DateTime createdAt;
  final String authorName;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) =>
      AppNotification(
        id: id,
        title: map['title'] as String,
        content: map['content'] as String,
        audience: Audience.values.byName(map['audience'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String),
        authorName: map['authorName'] as String,
      );

  Map<String, dynamic> toMap() => {
    'title': title,
    'content': content,
    'audience': audience.name,
    'createdAt': createdAt.toIso8601String(),
    'authorName': authorName,
  };
}
