import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_exception.dart';
import '../../core/constants.dart';
import '../models/app_user.dart';

/// Tên collection giữ mã người dùng toàn cục (`userCodes/{MÃ VIẾT HOA}`).
/// Không thêm vào [Collections] để giữ nguyên file hằng số dùng chung;
/// rules cho staff đọc/tạo collection này do main sở hữu (xem báo cáo).
const _userCodes = 'userCodes';

class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(Collections.users);

  CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection(_userCodes);

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

  /// Toàn bộ người dùng cho màn staff quản lý tài khoản (sắp theo mã).
  Future<List<AppUser>> all() async {
    final snap = await _users.get();
    return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  /// Mã đã được giữ trong `userCodes/{MÃ VIẾT HOA}` chưa.
  /// Seed backfill các mã có sẵn nên mã seed cũng bị chặn trùng ở đây.
  Future<bool> isCodeReserved(String code) async {
    final doc = await _codes.doc(code.trim().toUpperCase()).get();
    return doc.exists;
  }

  /// Ghi hồ sơ `users/{uid}` cùng đặt chỗ `userCodes/{MÃ VIẾT HOA}` trong
  /// một transaction trên Firestore mặc định của staff. Chỉ cho phép tạo
  /// sinh viên hoặc giảng viên (chặn nâng quyền staff/head từ client này).
  Future<void> createProfileWithCode({
    required String uid,
    required UserRole role,
    required String fullName,
    required String code,
    required String email,
    required String department,
  }) async {
    if (role != UserRole.student && role != UserRole.lecturer) {
      throw const AppException('Chỉ được tạo sinh viên hoặc giảng viên');
    }
    if (role == UserRole.lecturer &&
        department != 'SE' &&
        department != 'AI') {
      throw const AppException('Giảng viên cần bộ môn SE hoặc AI');
    }
    if (role == UserRole.student && department.isNotEmpty) {
      throw const AppException('Sinh viên không cần bộ môn');
    }
    final codeKey = code.trim().toUpperCase();
    try {
      await _db.runTransaction((tx) async {
        final codeRef = _codes.doc(codeKey);
        if ((await tx.get(codeRef)).exists) {
          throw AppException('Mã $codeKey đã tồn tại');
        }
        final userRef = _users.doc(uid);
        if ((await tx.get(userRef)).exists) {
          throw const AppException('Hồ sơ đã tồn tại');
        }
        tx.set(userRef, {
          'role': role.name,
          'fullName': fullName,
          'code': code,
          'email': email,
          'department': department,
        });
        tx.set(codeRef, {'uid': uid});
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppException(
        e.code == 'permission-denied'
            ? 'Bạn không có quyền thực hiện thao tác này'
            : 'Lỗi máy chủ: ${e.message ?? e.code}',
      );
    }
  }

  /// Đọc lại để phân giải commit mơ hồ sau lỗi ghi: true khi hồ sơ và đặt
  /// chỗ đều đã được ghi cho đúng [uid]. Lỗi đọc được để caller xử lý.
  Future<bool> isCommitted({required String uid, required String code}) =>
      _isCommitted(uid, code.trim().toUpperCase());

  Future<bool> _isCommitted(String uid, String codeKey) async {
    final user = await _users.doc(uid).get();
    if (!user.exists) return false;
    final reservation = await _codes.doc(codeKey).get();
    return reservation.exists && reservation.data()?['uid'] == uid;
  }
}
