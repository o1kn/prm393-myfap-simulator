import '../data/models/app_user.dart';
import '../data/models/application_form.dart';
import '../data/models/class_session.dart';
import '../data/models/course_class.dart';
import '../data/repositories/academic_repository.dart';
import '../data/repositories/application_repository.dart';
import 'base_view_model.dart';

/// Số liệu "việc cần làm ngay" trên Trang chủ, tính từ dữ liệu thật theo vai trò:
/// - sinh viên: buổi học hôm nay, đơn đang xử lý, buổi học tiếp theo
/// - giảng viên: buổi dạy hôm nay, bảng điểm cần nhập, buổi dạy tiếp theo
/// - trưởng bộ môn: bảng điểm chờ duyệt, lớp chưa có giảng viên
/// - cán bộ đào tạo: đơn đang xử lý, số lớp đã mở
class HomeViewModel extends BaseViewModel {
  HomeViewModel(this._academic, this._applications, this.user, {DateTime? now})
    : _now = now ?? DateTime.now();

  final AcademicRepository _academic;
  final ApplicationRepository _applications;
  final AppUser user;
  final DateTime _now;

  bool loaded = false;
  int todaySessions = 0;
  ClassSession? nextSession;
  int pendingApplications = 0;
  int gradesToEnter = 0;
  int gradesToApprove = 0;
  int unassignedClasses = 0;
  int openClasses = 0;

  DateTime get today => DateTime(_now.year, _now.month, _now.day);

  Future<void> load() async {
    final ok = await run(() async {
      switch (user.role) {
        case UserRole.student:
          await _loadSessions(await _academic.sessionsOfStudent(user.uid));
          pendingApplications = _processing(
            await _applications.ofStudent(user.uid),
          );
        case UserRole.lecturer:
          await _loadSessions(await _academic.sessionsOfLecturer(user.uid));
          final classes = await _academic.classesOfLecturer(user.uid);
          gradesToEnter = classes
              .where((c) => c.gradeStatus.lecturerCanEdit)
              .length;
        case UserRole.head:
          final classes = await _academic.classesOfDepartment(user.department);
          gradesToApprove = classes
              .where((c) => c.gradeStatus == GradeStatus.submitted)
              .length;
          unassignedClasses = classes.where((c) => c.lecturerId == null).length;
        case UserRole.staff:
          pendingApplications = _processing(await _applications.all());
          openClasses = (await _academic.allClasses()).length;
      }
    });
    loaded = ok;
    notify();
  }

  int _processing(List<ApplicationForm> forms) =>
      forms.where((f) => f.status == ApplicationStatus.processing).length;

  Future<void> _loadSessions(List<ClassSession> sessions) async {
    final upcoming = sessions.where((s) => !s.date.isBefore(today)).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.slot.compareTo(b.slot);
      });
    todaySessions = upcoming.where((s) => s.date == today).length;
    nextSession = upcoming.isEmpty ? null : upcoming.first;
  }
}
