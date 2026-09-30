import '../core/app_exception.dart';
import '../data/models/app_user.dart';
import '../data/models/class_session.dart';
import '../data/models/course_class.dart';
import '../data/models/grade_record.dart';
import '../data/models/subject.dart';
import '../data/repositories/academic_repository.dart';
import '../data/repositories/grade_repository.dart';
import '../data/repositories/user_repository.dart';
import '../domain/attendance_rules.dart';
import '../domain/grade_rules.dart';
import 'base_view_model.dart';

/// Bảng điểm một lớp. Giảng viên nhập / gửi duyệt; trưởng bộ môn dùng cùng
/// dữ liệu này ở chế độ chỉ xem để công bố hoặc trả lại.
class GradeSheetViewModel extends BaseViewModel {
  GradeSheetViewModel(
    this._academic,
    this._grades,
    this._users,
    this.course,
    this.viewer,
  );

  final AcademicRepository _academic;
  final GradeRepository _grades;
  final UserRepository _users;

  /// Người đang xem bảng điểm: chọn đúng truy vấn buổi học mà rules cho phép
  /// (giảng viên phải lọc thêm `lecturerId`, xem [AcademicRepository]).
  final AppUser viewer;

  CourseClass course;
  Subject? subject;
  List<AppUser> students = const [];
  List<ClassSession> sessions = const [];

  /// uid sinh viên → (tên đầu điểm → điểm).
  final Map<String, Map<String, double>> marks = {};

  /// Các ô có nội dung không hợp lệ (`'uid|đầu điểm'`). Ô lỗi thì chưa xác
  /// định được điểm, nên phải chặn cả lưu nháp và gửi duyệt.
  final Set<String> invalidCells = {};

  /// Ảnh chụp điểm sau lần tải/lưu thành công gần nhất. Màn hình so [marks]
  /// với ảnh này (kèm [invalidCells]) để chặn nút back khi còn thay đổi.
  Map<String, Map<String, double>> _saved = {};

  bool get editable => course.gradeStatus.lecturerCanEdit;

  /// Còn thay đổi chưa lưu, kể cả ô nhập sai (điểm cũ chưa ghi đè nhưng UI
  /// đang báo đỏ thì vẫn tính là bẩn để không mất dấu lỗi khi back).
  bool get hasUnsavedChanges {
    if (invalidCells.isNotEmpty) return true;
    if (_saved.length != marks.length) return true;
    for (final e in marks.entries) {
      final old = _saved[e.key];
      if (old == null || old.length != e.value.length) return true;
      for (final m in e.value.entries) {
        if (old[m.key] != m.value) return true;
      }
    }
    return false;
  }

  Future<void> load() => run(() async {
    course = await _academic.classById(course.id);
    subject = (await _academic.subjectsByCode())[course.subjectCode];
    students = await _users.byIds(course.studentIds);
    sessions = viewer.role == UserRole.lecturer
        ? await _academic.sessionsOfLecturerInClass(course.id, viewer.uid)
        : await _academic.sessionsOfClass(course.id);
    final existing = {
      for (final r in await _grades.gradesOfClass(course.id)) r.studentId: r,
    };
    marks
      ..clear()
      ..addAll({
        for (final s in students) s.uid: {...?existing[s.uid]?.marks},
      });
    invalidCells.clear();
    _takeSnapshot();
  });

  void _takeSnapshot() {
    _saved = {for (final e in marks.entries) e.key: Map.of(e.value)};
  }

  /// Ghi điểm vừa nhập; [input] rỗng = xoá điểm. Trả về lỗi hoặc null.
  ///
  /// Input sai không ghi đè điểm cũ nhưng ô được đánh dấu lỗi để [_save]
  /// chặn lại, tránh lưu điểm cũ trong khi UI đang báo đỏ.
  String? setMark(String studentId, String component, String input) {
    final key = '$studentId|$component';
    if (input.trim().isEmpty) {
      marks[studentId]?.remove(component);
      invalidCells.remove(key);
      notify();
      return null;
    }
    final error = validateMark(input);
    if (error != null) {
      invalidCells.add(key);
      notify();
      return error;
    }
    invalidCells.remove(key);
    (marks[studentId] ??= {})[component] = double.parse(
      input.trim().replaceAll(',', '.'),
    );
    notify();
    return null;
  }

  /// Tải hỏng giữa chừng (ví dụ truy vấn buổi học bị rules từ chối) không
  /// được làm sập màn hình: thiếu dữ liệu thì coi như chưa nhập điểm.
  Map<String, double> marksOf(String studentId) =>
      marks[studentId] ?? const {};

  double? averageOf(String studentId) =>
      subject == null ? null : weightedAverage(subject!, marksOf(studentId));

  int get completeCount =>
      subject == null
          ? 0
          : students.where((s) => isComplete(subject!, marksOf(s.uid))).length;

  Future<bool> saveDraft() => _save(submit: false);

  /// Gửi trưởng bộ môn duyệt: bắt buộc đủ mọi đầu điểm của mọi sinh viên.
  Future<bool> submit() => _save(submit: true);

  Future<bool> _save({required bool submit}) => run(() async {
    if (!editable) {
      throw const AppException('Bảng điểm đã gửi duyệt, không thể sửa');
    }
    if (invalidCells.isNotEmpty) {
      throw const AppException('Còn ô điểm không hợp lệ, kiểm tra lại');
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
          marks: Map.of(marksOf(s.uid)),
        ),
    ], submit: submit);
    course = await _academic.classById(course.id);
    // Chỉ lưu thất bại (throw ở trên) mới giữ nguyên vết bẩn để back chặn
    // lại; thành công thì chốt ảnh mới.
    _takeSnapshot();
  });

  /// Tổng hợp điểm danh của một sinh viên trong lớp này. Chỉ tính các buổi
  /// mà sinh viên còn trong danh sách (`studentIds` chứa uid, kể cả buổi
  /// tương lai) — sinh viên vào muộn không gánh buổi cũ; khớp cách tính ở
  /// Attendance report và Grade report.
  AttendanceSummary summaryOf(String studentId) => AttendanceSummary.of(
    sessions.where((s) => s.studentIds.contains(studentId)),
    studentId,
  );
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
