import '../data/models/app_user.dart';
import '../data/models/class_session.dart';
import '../data/repositories/academic_repository.dart';
import '../domain/schedule_rules.dart';
import 'base_view_model.dart';

/// Lịch theo tuần (Weekly timetable). Sinh viên thấy lịch học kèm trạng thái
/// điểm danh; giảng viên / trưởng bộ môn thấy lịch dạy.
class TimetableViewModel extends BaseViewModel {
  TimetableViewModel(this._repo, this.user, {DateTime? today})
    : _week = mondayOf(today ?? DateTime.now());

  final AcademicRepository _repo;
  final AppUser user;

  List<ClassSession> _sessions = const [];
  DateTime _week;

  DateTime get weekStart => _week;
  DateTime get weekEnd => DateTime(_week.year, _week.month, _week.day + 6);

  bool get isStudent => user.role == UserRole.student;

  Future<void> load() => run(() async {
    _sessions = isStudent
        ? await _repo.sessionsOfStudent(user.uid)
        : await _repo.sessionsOfLecturer(user.uid);
  });

  /// 7 ngày của tuần đang xem, mỗi ngày kèm các buổi học đã sắp theo slot.
  List<(DateTime, List<ClassSession>)> get days => [
    for (var i = 0; i < 7; i++)
      (
        DateTime(_week.year, _week.month, _week.day + i),
        _sessions
            .where(
              (s) => s.date == DateTime(_week.year, _week.month, _week.day + i),
            )
            .toList(),
      ),
  ];

  void previousWeek() => _moveWeek(-7);
  void nextWeek() => _moveWeek(7);

  void currentWeek() {
    _week = mondayOf(DateTime.now());
    notify();
  }

  void _moveWeek(int days) {
    _week = DateTime(_week.year, _week.month, _week.day + days);
    notify();
  }
}
