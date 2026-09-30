/// Một đầu điểm trong cấu trúc điểm môn học (tên + trọng số %).
class GradeComponent {
  const GradeComponent({
    required this.name,
    required this.weight,
    this.isFinal = false,
  });

  final String name;

  /// Trọng số theo phần trăm; tổng các đầu điểm của một môn = 100.
  final double weight;

  /// Đầu điểm thi cuối kỳ (Final Exam) có điều kiện điểm sàn riêng.
  final bool isFinal;

  factory GradeComponent.fromMap(Map<String, dynamic> map) => GradeComponent(
    name: map['name'] as String,
    weight: (map['weight'] as num).toDouble(),
    isFinal: map['isFinal'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'weight': weight,
    'isFinal': isFinal,
  };
}

/// Môn học, document `subjects/{code}`.
class Subject {
  const Subject({
    required this.code,
    required this.name,
    required this.credits,
    required this.department,
    required this.totalSessions,
    required this.components,
  });

  final String code;
  final String name;
  final int credits;

  /// Bộ môn quản lý môn học; trưởng bộ môn chỉ thao tác lớp thuộc bộ môn mình.
  final String department;

  /// Số buổi học của một lớp môn (dùng khi xếp lịch).
  final int totalSessions;
  final List<GradeComponent> components;

  factory Subject.fromMap(String code, Map<String, dynamic> map) => Subject(
    code: code,
    name: map['name'] as String,
    credits: (map['credits'] as num).toInt(),
    department: map['department'] as String,
    totalSessions: (map['totalSessions'] as num).toInt(),
    components: (map['components'] as List)
        .map((c) => GradeComponent.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList(),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'credits': credits,
    'department': department,
    'totalSessions': totalSessions,
    'components': components.map((c) => c.toMap()).toList(),
  };
}
