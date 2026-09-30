/// Điểm của một sinh viên trong một lớp môn, document
/// `grades/{classId}_{studentId}`.
class GradeRecord {
  const GradeRecord({
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.subjectCode,
    required this.semester,
    required this.marks,
    this.published = false,
  });

  final String classId;
  final String studentId;
  final String studentName;
  final String studentCode;
  final String subjectCode;
  final String semester;

  /// Tên đầu điểm → điểm (0..10). Thiếu khoá = chưa nhập.
  final Map<String, double> marks;

  /// Chép từ trạng thái lớp khi trưởng bộ môn công bố; luật bảo mật
  /// Firestore dựa vào trường này để chỉ cho sinh viên đọc điểm đã công bố.
  final bool published;

  String get id => docId(classId, studentId);

  static String docId(String classId, String studentId) =>
      '${classId}_$studentId';

  GradeRecord copyWith({Map<String, double>? marks, bool? published}) =>
      GradeRecord(
        classId: classId,
        studentId: studentId,
        studentName: studentName,
        studentCode: studentCode,
        subjectCode: subjectCode,
        semester: semester,
        marks: marks ?? this.marks,
        published: published ?? this.published,
      );

  factory GradeRecord.fromMap(Map<String, dynamic> map) => GradeRecord(
    classId: map['classId'] as String,
    studentId: map['studentId'] as String,
    studentName: map['studentName'] as String,
    studentCode: map['studentCode'] as String,
    subjectCode: map['subjectCode'] as String,
    semester: map['semester'] as String,
    marks: {
      for (final e in Map<String, dynamic>.from(map['marks'] as Map).entries)
        e.key: (e.value as num).toDouble(),
    },
    published: map['published'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'classId': classId,
    'studentId': studentId,
    'studentName': studentName,
    'studentCode': studentCode,
    'subjectCode': subjectCode,
    'semester': semester,
    'marks': marks,
    'published': published,
  };
}
