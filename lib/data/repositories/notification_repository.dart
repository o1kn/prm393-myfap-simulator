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
    final snap = await _items.get();
    return snap.docs
        .map((d) => AppNotification.fromMap(d.id, d.data()))
        .where((n) => role == UserRole.staff || n.audience.includes(role))
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
