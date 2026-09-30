import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_exception.dart';
import '../../core/constants.dart';
import '../models/app_user.dart';
import '../models/application_form.dart';

/// Sinh viên gửi đơn → cán bộ đào tạo chấp nhận / từ chối.
class ApplicationRepository {
  ApplicationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _apps =>
      _db.collection(Collections.applications);

  Future<List<ApplicationForm>> ofStudent(String uid) =>
      _query(_apps.where('studentId', isEqualTo: uid));

  Future<List<ApplicationForm>> all() => _query(_apps);

  Future<List<ApplicationForm>> _query(
    Query<Map<String, dynamic>> query,
  ) async {
    final snap = await query.get();
    return snap.docs
        .map((d) => ApplicationForm.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> submit(AppUser student, String type, String content) async {
    if (content.trim().length < 10) {
      throw const AppException('Nội dung đơn cần ít nhất 10 ký tự');
    }
    final ref = _apps.doc();
    await ref.set(
      ApplicationForm(
        id: ref.id,
        studentId: student.uid,
        studentName: student.fullName,
        studentCode: student.code,
        type: type,
        content: content.trim(),
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  /// Đọc lại trạng thái trong transaction: hai cán bộ cùng mở một đơn thì
  /// chỉ người xử lý trước thành công.
  Future<void> process(
    ApplicationForm form, {
    required ApplicationStatus decision,
    required String note,
    required AppUser staff,
  }) async {
    if (decision == ApplicationStatus.rejected && note.trim().isEmpty) {
      throw const AppException('Nhập lý do khi từ chối đơn');
    }
    final ref = _apps.doc(form.id);
    await _db.runTransaction((tx) async {
      final current = await tx.get(ref);
      if (current.data()?['status'] != ApplicationStatus.processing.name) {
        throw const AppException('Đơn này đã được xử lý');
      }
      tx.update(ref, {
        'status': decision.name,
        'staffNote': note.trim(),
        'processedBy': staff.fullName,
        'processedAt': DateTime.now().toIso8601String(),
      });
    });
  }
}
