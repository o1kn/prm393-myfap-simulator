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
  int _selectedWeekday = 1; // 1..7 theo DateTime.weekday.

  bool get isStudent => user.role == UserRole.student;

  Future<void> load() => run(() async {
    _sessions = isStudent
        ? await _repo.sessionsOfStudent(user.uid)
        : await _repo.sessionsOfLecturer(user.uid);
    _snapToToday();
  });

  DateTime get weekStart => _week;
  DateTime get weekEnd => DateTime(_week.year, _week.month, _week.day + 6);

  /// Ngày đang chọn trong thanh ngày ở đầu màn hình.
  DateTime get selectedDay => DateTime(
    _week.year,
    _week.month,
    _week.day + _selectedWeekday - 1,
  );

  List<ClassSession> get sessionsOfSelectedDay => _sessions
      .where((s) => s.date == selectedDay)
      .toList()
    ..sort((a, b) => a.slot.compareTo(b.slot));

  bool hasSessionsOn(DateTime day) =>
      _sessions.any((s) => s.date == day);

  void selectDay(int weekday) {
    _selectedWeekday = weekday;
    notify();
  }

  /// Lịch của tuần (dùng cho thanh ngày ở đầu màn hình).
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
    _snapToToday();
    notify();
  }

  void _moveWeek(int days) {
    _week = DateTime(_week.year, _week.month, _week.day + days);
    _snapToToday();
    notify();
  }

  /// Sang tuần khác thì chọn lại Thứ 2; về tuần hiện tại thì chọn hôm nay.
  void _snapToToday() {
    final monday = mondayOf(DateTime.now());
    _selectedWeekday = _week == monday ? DateTime.now().weekday : 1;
  }
}
