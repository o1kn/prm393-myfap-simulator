import '../../data/models/app_user.dart';
import '../../data/models/class_session.dart';
import '../../data/models/course_class.dart';
import '../../data/repositories/academic_repository.dart';
import '../../domain/attendance_rules.dart';
import '../base_view_model.dart';

/// Attendance report: chọn lớp môn → danh sách buổi + tỉ lệ vắng.
class AttendanceReportViewModel extends BaseViewModel {
  AttendanceReportViewModel(this._repo, this.student);

  final AcademicRepository _repo;
  final AppUser student;

  List<CourseClass> classes = const [];
  List<ClassSession> _sessions = const [];
  String? selectedClassId;

  Future<void> load() => run(() async {
    classes = await _repo.classesOfStudent(student.uid);
    _sessions = await _repo.sessionsOfStudent(student.uid);
    selectedClassId ??= classes.isEmpty ? null : classes.first.id;
  });

  void select(String classId) {
    selectedClassId = classId;
    notify();
  }

  CourseClass? get selectedClass =>
      classes.where((c) => c.id == selectedClassId).firstOrNull;

  List<ClassSession> get sessions =>
      _sessions.where((s) => s.classId == selectedClassId).toList();

  AttendanceSummary get summary => AttendanceSummary.of(sessions, student.uid);
}
