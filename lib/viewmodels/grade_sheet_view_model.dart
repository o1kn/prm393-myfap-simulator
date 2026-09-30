import '../core/app_exception.dart';
import '../data/models/app_user.dart';
import '../data/models/course_class.dart';
import '../data/models/grade_record.dart';
import '../data/models/subject.dart';
import '../data/repositories/academic_repository.dart';
import '../data/repositories/grade_repository.dart';
import '../data/repositories/user_repository.dart';
import '../domain/grade_rules.dart';
import 'base_view_model.dart';

/// Bảng điểm một lớp. Giảng viên nhập / gửi duyệt; trưởng bộ môn dùng cùng
/// dữ liệu này ở chế độ chỉ xem để công bố hoặc trả lại.
class GradeSheetViewModel extends BaseViewModel {
  GradeSheetViewModel(this._academic, this._grades, this._users, this.course);

  final AcademicRepository _academic;
  final GradeRepository _grades;
  final UserRepository _users;

  CourseClass course;
  Subject? subject;
  List<AppUser> students = const [];

  /// uid sinh viên → (tên đầu điểm → điểm).
  final Map<String, Map<String, double>> marks = {};

  bool get editable => course.gradeStatus.lecturerCanEdit;

  Future<void> load() => run(() async {
    course = await _academic.classById(course.id);
    subject = (await _academic.subjectsByCode())[course.subjectCode];
    students = await _users.byIds(course.studentIds);
    final existing = {
      for (final r in await _grades.gradesOfClass(course.id)) r.studentId: r,
    };
    marks
      ..clear()
      ..addAll({
        for (final s in students) s.uid: {...?existing[s.uid]?.marks},
      });
  });

  /// Ghi điểm vừa nhập; [input] rỗng = xoá điểm. Trả về lỗi hoặc null.
  String? setMark(String studentId, String component, String input) {
    if (input.trim().isEmpty) {
      marks[studentId]!.remove(component);
      notify();
      return null;
    }
    final error = validateMark(input);
    if (error != null) return error;
    marks[studentId]![component] = double.parse(
      input.trim().replaceAll(',', '.'),
    );
    notify();
    return null;
  }

  double? averageOf(String studentId) =>
      weightedAverage(subject!, marks[studentId]!);

  int get completeCount =>
      students.where((s) => isComplete(subject!, marks[s.uid]!)).length;

  Future<bool> saveDraft() => _save(submit: false);

  /// Gửi trưởng bộ môn duyệt: bắt buộc đủ mọi đầu điểm của mọi sinh viên.
  Future<bool> submit() => _save(submit: true);

  Future<bool> _save({required bool submit}) => run(() async {
    if (!editable) {
      throw const AppException('Bảng điểm đã gửi duyệt, không thể sửa');
    }
    if (submit && completeCount < students.length) {
      throw AppException(
        'Còn ${students.length - completeCount} sinh viên chưa đủ đầu điểm',
      );
    }
    await _grades.saveGrades(course, [
      for (final s in students)
        GradeRecord(
          classId: course.id,
          studentId: s.uid,
          studentName: s.fullName,
          studentCode: s.code,
          subjectCode: course.subjectCode,
          semester: course.semester,
          marks: Map.of(marks[s.uid]!),
        ),
    ], submit: submit);
    course = await _academic.classById(course.id);
  });

  // ---------- Trưởng bộ môn ----------

  Future<bool> publish() => run(() async {
    if (course.gradeStatus != GradeStatus.submitted) {
      throw const AppException('Chỉ công bố bảng điểm đang chờ duyệt');
    }
    await _grades.publish(course);
    course = await _academic.classById(course.id);
  });

  Future<bool> returnToLecturer(String note) => run(() async {
    if (note.trim().isEmpty) {
      throw const AppException('Nhập lý do trả lại');
    }
    await _grades.returnToLecturer(course, note);
    course = await _academic.classById(course.id);
  });
}
