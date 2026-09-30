import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(Collections.users);

  /// Hồ sơ theo danh sách uid, sắp theo mã (Firestore giới hạn 30 phần tử
  /// mỗi truy vấn `whereIn` nên chia lô).
  Future<List<AppUser>> byIds(List<String> uids) async {
    final result = <AppUser>[];
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(
        i,
        i + 30 > uids.length ? uids.length : i + 30,
      );
      final snap = await _users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      result.addAll(snap.docs.map((d) => AppUser.fromMap(d.id, d.data())));
    }
    return result..sort((a, b) => a.code.compareTo(b.code));
  }

  Future<List<AppUser>> students() async {
    final snap = await _users
        .where('role', isEqualTo: UserRole.student.name)
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  Future<List<AppUser>> lecturersOf(String department) async {
    final snap = await _users
        .where('role', isEqualTo: UserRole.lecturer.name)
        .where('department', isEqualTo: department)
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }
}
