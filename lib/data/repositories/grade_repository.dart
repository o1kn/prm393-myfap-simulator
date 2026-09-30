import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../models/course_class.dart';
import '../models/grade_record.dart';

/// Nhập điểm (giảng viên) → gửi duyệt → công bố / trả lại (trưởng bộ môn).
class GradeRepository {
  GradeRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _grades =>
      _db.collection(Collections.grades);
  CollectionReference<Map<String, dynamic>> get _classes =>
      _db.collection(Collections.classes);

  Future<List<GradeRecord>> gradesOfClass(String classId) async {
    final snap = await _grades.where('classId', isEqualTo: classId).get();
    return snap.docs.map((d) => GradeRecord.fromMap(d.data())).toList();
  }

  /// Sinh viên chỉ đọc được điểm đã công bố (luật bảo mật cũng chặn phần còn lại).
  Future<List<GradeRecord>> publishedGradesOf(String studentId) async {
    final snap = await _grades
        .where('studentId', isEqualTo: studentId)
        .where('published', isEqualTo: true)
        .get();
    return snap.docs.map((d) => GradeRecord.fromMap(d.data())).toList();
  }

  /// Lưu nháp; nếu [submit] thì đồng thời chuyển lớp sang "Chờ duyệt".
  Future<void> saveGrades(
    CourseClass course,
    List<GradeRecord> records, {
    required bool submit,
  }) async {
    final batch = _db.batch();
    for (final r in records) {
      batch.set(_grades.doc(r.id), r.toMap());
    }
    if (submit) {
      batch.update(_classes.doc(course.id), {
        'gradeStatus': GradeStatus.submitted.name,
        'headNote': '',
      });
    }
    await batch.commit();
  }

  /// Công bố: lớp → published và bật cờ `published` trên từng bản ghi điểm.
  Future<void> publish(CourseClass course) async {
    final records = await gradesOfClass(course.id);
    final batch = _db.batch()
      ..update(_classes.doc(course.id), {
        'gradeStatus': GradeStatus.published.name,
      });
    for (final r in records) {
      batch.update(_grades.doc(r.id), {'published': true});
    }
    await batch.commit();
  }

  Future<void> returnToLecturer(CourseClass course, String note) =>
      _classes.doc(course.id).update({
        'gradeStatus': GradeStatus.returned.name,
        'headNote': note.trim(),
      });
}
