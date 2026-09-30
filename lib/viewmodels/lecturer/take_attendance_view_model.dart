import '../../core/app_exception.dart';
import '../../data/models/app_user.dart';
import '../../data/models/class_session.dart';
import '../../data/models/course_class.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/attendance_rules.dart';
import '../base_view_model.dart';

/// Giảng viên điểm danh một buổi học.
class TakeAttendanceViewModel extends BaseViewModel {
  TakeAttendanceViewModel(
    this._academic,
    this._users,
    this.session, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final AcademicRepository _academic;
  final UserRepository _users;
  final ClassSession session;
  final DateTime Function() _clock;

  List<AppUser> students = const [];
  final Map<String, AttendanceStatus> marks = {};

  /// Lớp hiện tại (tải mới mỗi lần [load]). Lớp đã công bố thì khoá sửa.
  /// Null khi lớp cũ/thiếu document — coi như chưa công bố để tương thích
  /// dữ liệu seed cũ (màn điểm danh widget test chỉ seed buổi học).
  CourseClass? courseClass;

  /// Ảnh điểm danh sau lần tải/lưu thành công gần nhất.
  Map<String, AttendanceStatus> _saved = {};

  /// Lớp đã công bố thì khoá sửa điểm danh (quy định mới).
  bool get isPublished =>
      courseClass?.gradeStatus == GradeStatus.published;

  /// Buổi chưa tới ngày thì chỉ xem, không điểm danh.
  bool get editable => !isPublished && canTakeAttendance(session, _clock());

  /// Lý do chỉ xem: phân biệt đã công bố / chưa tới ngày để màn hình hiện
  /// đúng câu chữ (giữ nguyên câu cũ cho buổi tương lai).
  String? get readonlyReason {
    if (isPublished) {
      return 'Lớp đã công bố: điểm danh chỉ xem, không thể sửa.';
    }
    if (!canTakeAttendance(session, _clock())) {
      return 'Buổi học chưa diễn ra: chỉ xem, chưa điểm danh được.';
    }
    return null;
  }

  bool get hasUnsavedChanges {
    if (_saved.length != marks.length) return marks.isNotEmpty;
    for (final e in marks.entries) {
      if (_saved[e.key] != e.value) return true;
    }
    return false;
  }

  int get absentCount =>
      marks.values.where((m) => m == AttendanceStatus.absent).length;

  Future<void> load() => run(() async {
    try {
      courseClass = await _academic.classById(session.classId);
    } catch (_) {
      // Lớp cũ/thiếu document: coi như chưa công bố, giữ hành vi cũ.
      courseClass = null;
    }
    students = await _users.byIds(session.studentIds);
    // Buổi đã tới ngày mà chưa điểm danh: mặc định có mặt, giảng viên chỉ
    // bấm người vắng. Buổi chưa tới ngày hoặc lớp đã công bố: hiện
    // "Chưa diễn ra", không tự dựng lịch sử có mặt.
    final fallback = editable
        ? AttendanceStatus.present
        : AttendanceStatus.notYet;
    marks
      ..clear()
      ..addAll({
        for (final s in students) s.uid: session.attendance[s.uid] ?? fallback,
      });
    _saved = Map.of(marks);
  });

  void toggle(String studentId) {
    if (!editable) return;
    marks[studentId] = marks[studentId] == AttendanceStatus.absent
        ? AttendanceStatus.present
        : AttendanceStatus.absent;
    notify();
  }

  Future<bool> save() => run(() async {
    if (isPublished) {
      throw const AppException('Lớp đã công bố, không thể sửa điểm danh');
    }
    if (!editable) {
      throw const AppException('Chưa đến ngày học, không thể điểm danh');
    }
    await _academic.saveAttendance(session.id, Map.of(marks));
    // Thất bại (throw ở trên) giữ nguyên vết bẩn; thành công chốt ảnh mới.
    _saved = Map.of(marks);
  });
}
