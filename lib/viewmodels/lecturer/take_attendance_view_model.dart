import '../../core/app_exception.dart';
import '../../data/models/app_user.dart';
import '../../data/models/class_session.dart';
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

  /// Buổi chưa tới ngày thì chỉ xem, không điểm danh.
  bool get editable => canTakeAttendance(session, _clock());

  int get absentCount =>
      marks.values.where((m) => m == AttendanceStatus.absent).length;

  Future<void> load() => run(() async {
    students = await _users.byIds(session.studentIds);
    marks
      ..clear()
      ..addAll({
        // Chưa điểm danh thì mặc định có mặt; giảng viên chỉ bấm người vắng.
        for (final s in students)
          s.uid: session.attendance[s.uid] ?? AttendanceStatus.present,
      });
  });

  void toggle(String studentId) {
    if (!editable) return;
    marks[studentId] = marks[studentId] == AttendanceStatus.absent
        ? AttendanceStatus.present
        : AttendanceStatus.absent;
    notify();
  }

  Future<bool> save() => run(() async {
    if (!editable) {
      throw const AppException('Chưa đến ngày học, không thể điểm danh');
    }
    await _academic.saveAttendance(session.id, Map.of(marks));
  });
}
