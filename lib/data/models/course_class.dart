/// Trạng thái bảng điểm của một lớp môn.
enum GradeStatus {
  /// Giảng viên đang nhập điểm.
  draft('Đang nhập điểm'),

  /// Giảng viên đã gửi, chờ trưởng bộ môn duyệt; giảng viên không sửa được.
  submitted('Chờ duyệt'),

  /// Trưởng bộ môn trả lại; giảng viên sửa rồi gửi lại.
  returned('Bị trả lại'),

  /// Đã công bố; sinh viên thấy điểm.
  published('Đã công bố');

  const GradeStatus(this.label);

  final String label;

  bool get lecturerCanEdit =>
      this == GradeStatus.draft || this == GradeStatus.returned;
}

/// Lớp môn (một môn học mở cho một nhóm sinh viên trong một học kỳ),
/// document `classes/{id}`.
class CourseClass {
  const CourseClass({
    required this.id,
    required this.code,
    required this.subjectCode,
    required this.subjectName,
    required this.semester,
    required this.department,
    required this.studentIds,
    this.lecturerId,
    this.lecturerName,
    this.gradeStatus = GradeStatus.draft,
    this.headNote = '',
  });

  final String id;

  /// Mã lớp, VD `SE1943`.
  final String code;
  final String subjectCode;
  final String subjectName;
  final String semester;
  final String department;
  final List<String> studentIds;

  /// Giảng viên do trưởng bộ môn phân công; null = chưa phân công.
  final String? lecturerId;
  final String? lecturerName;
  final GradeStatus gradeStatus;

  /// Nhận xét của trưởng bộ môn khi trả lại bảng điểm.
  final String headNote;

  String get title => '$subjectCode - $code';

  factory CourseClass.fromMap(String id, Map<String, dynamic> map) =>
      CourseClass(
        id: id,
        code: map['code'] as String,
        subjectCode: map['subjectCode'] as String,
        subjectName: map['subjectName'] as String,
        semester: map['semester'] as String,
        department: map['department'] as String,
        studentIds: List<String>.from(map['studentIds'] as List),
        lecturerId: map['lecturerId'] as String?,
        lecturerName: map['lecturerName'] as String?,
        gradeStatus: GradeStatus.values.byName(
          map['gradeStatus'] as String? ?? GradeStatus.draft.name,
        ),
        headNote: map['headNote'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
    'code': code,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'semester': semester,
    'department': department,
    'studentIds': studentIds,
    'lecturerId': lecturerId,
    'lecturerName': lecturerName,
    'gradeStatus': gradeStatus.name,
    'headNote': headNote,
  };
}
