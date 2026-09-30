import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_exception.dart';
import '../../core/constants.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';

class NotificationRepository {
  NotificationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection(Collections.notifications);

  /// Thông báo dành cho [role], mới nhất trước.
  Future<List<AppNotification>> forRole(UserRole role) async {
    final query = role == UserRole.staff
        ? _items
        : _items.where('audience', whereIn: [
            Audience.all.name,
            role == UserRole.student
                ? Audience.students.name
                : Audience.lecturers.name,
          ]);
    final snap = await query.get();
    return snap.docs
        .map((d) => AppNotification.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> publish({
    required AppUser author,
    required String title,
    required String content,
    required Audience audience,
  }) async {
    if (title.trim().isEmpty || content.trim().isEmpty) {
      throw const AppException('Nhập đủ tiêu đề và nội dung');
    }
    if (title.trim().length > 200 || content.trim().length > 2000) {
      throw const AppException('Tiêu đề tối đa 200, nội dung tối đa 2000 ký tự');
    }
    final ref = _items.doc();
    await ref.set(
      AppNotification(
        id: ref.id,
        title: title.trim(),
        content: content.trim(),
        audience: audience,
        createdAt: DateTime.now(),
        authorName: author.fullName,
      ).toMap(),
    );
  }
}
