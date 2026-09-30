import '../../data/models/app_user.dart';
import '../../data/models/class_session.dart';
import '../../data/models/course_class.dart';
import '../../data/repositories/academic_repository.dart';
import '../../domain/attendance_rules.dart';
import '../base_view_model.dart';

/// Attendance report: chọn lớp môn → danh sách buổi + tỉ lệ vắng.
/// [initialClassId] preselect lớp khi mở từ Điểm học kỳ, giữ nguyên khi refresh.
/// Mẫu số = các buổi có studentIds chứa uid (gồm cả buổi chưa diễn ra),
/// đúng hợp đồng late-enrollment: không suy ra lịch từ Subject.totalSessions.
class AttendanceReportViewModel extends BaseViewModel {
  AttendanceReportViewModel(this._repo, this.student, {this.initialClassId});

  final AcademicRepository _repo;
  final AppUser student;
  final String? initialClassId;

  List<CourseClass> classes = const [];
  List<ClassSession> _sessions = const [];
  String? selectedClassId;

  Future<void> load() => run(() async {
    classes = await _repo.classesOfStudent(student.uid);
    _sessions = await _repo.sessionsOfStudent(student.uid);
    if (classes.isEmpty) {
      selectedClassId = null;
    } else if (classes.any((c) => c.id == selectedClassId)) {
      // Giữ lựa chọn hiện tại khi refresh.
    } else if (initialClassId != null &&
        classes.any((c) => c.id == initialClassId)) {
      selectedClassId = initialClassId;
    } else {
      selectedClassId = classes.first.id;
    }
  });

  void select(String classId) {
    selectedClassId = classId;
    notify();
  }

  CourseClass? get selectedClass =>
      classes.where((c) => c.id == selectedClassId).firstOrNull;

  List<ClassSession> get sessions =>
      _sessions.where((s) => s.classId == selectedClassId).toList();

  AttendanceSummary get summary => summaryFor(selectedClassId);

  /// Tổng hợp cho tổng quan tất cả các môn, cùng mẫu số đã gán cho sinh viên.
  AttendanceSummary summaryFor(String? classId) => AttendanceSummary.of(
        _sessions.where((s) => s.classId == classId),
        student.uid,
      );
}
