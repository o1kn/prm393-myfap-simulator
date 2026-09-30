import '../../data/models/app_user.dart';
import '../../data/models/course_class.dart';
import '../../data/models/grade_record.dart';
import '../../data/models/subject.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/grade_repository.dart';
import '../../domain/attendance_rules.dart';
import '../../domain/grade_rules.dart';
import '../base_view_model.dart';

/// Một dòng kết quả môn học của sinh viên.
class CourseResultRow {
  const CourseResultRow({
    required this.course,
    required this.subject,
    required this.record,
    required this.result,
  });

  final CourseClass course;
  final Subject subject;

  /// Null khi điểm chưa công bố.
  final GradeRecord? record;
  final CourseResult result;
}

/// Dữ liệu chung cho Grade report (theo từng lớp) và Academic transcript.
/// [initialClassId] preselect lớp khi mở từ Bảng điểm, giữ nguyên khi refresh.
class ResultsViewModel extends BaseViewModel {
  ResultsViewModel(this._academic, this._grades, this.student,
      {this.initialClassId});

  final AcademicRepository _academic;
  final GradeRepository _grades;
  final AppUser student;
  final String? initialClassId;

  List<CourseResultRow> rows = const [];
  String? selectedClassId;

  Future<void> load() => run(() async {
    final classes = await _academic.classesOfStudent(student.uid);
    final subjects = await _academic.subjectsByCode();
    final sessions = await _academic.sessionsOfStudent(student.uid);
    final records = {
      for (final r in await _grades.publishedGradesOf(student.uid))
        r.classId: r,
    };
    rows = [
      for (final c in classes)
        if (subjects[c.subjectCode] case final subject?)
          CourseResultRow(
            course: c,
            subject: subject,
            record: records[c.id],
            result: evaluate(
              subject,
              records[c.id]?.marks ?? const {},
              published: records.containsKey(c.id),
              attendanceBanned: AttendanceSummary.of(
                sessions.where((s) => s.classId == c.id),
                student.uid,
              ).isBanned,
            ),
          ),
    ];
    if (rows.isEmpty) {
      selectedClassId = null;
    } else if (rows.any((r) => r.course.id == selectedClassId)) {
      // Giữ lựa chọn hiện tại khi refresh.
    } else if (initialClassId != null &&
        rows.any((r) => r.course.id == initialClassId)) {
      selectedClassId = initialClassId;
    } else {
      selectedClassId = rows.first.course.id;
    }
  });

  void select(String classId) {
    selectedClassId = classId;
    notify();
  }

  CourseResultRow? get selected =>
      rows.where((r) => r.course.id == selectedClassId).firstOrNull;

  /// Tổng tín chỉ đã qua, cho phần tóm tắt bảng điểm.
  int get passedCredits => rows
      .where((r) => r.result.status == CourseStatus.passed)
      .fold(0, (sum, r) => sum + r.subject.credits);
}
