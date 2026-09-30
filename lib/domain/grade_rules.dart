import '../data/models/subject.dart';

/// Kết quả môn học, dùng chung cho Grade report và Academic transcript.
enum CourseStatus {
  studying('Đang học'),
  passed('Passed'),
  notPassed('Not passed');

  const CourseStatus(this.label);

  final String label;
}

/// Điểm sàn bài thi cuối kỳ và điểm trung bình tối thiểu để qua môn.
const minFinalMark = 4.0;
const minAverage = 5.0;

class CourseResult {
  const CourseResult(this.status, {this.average, this.reason = ''});

  final CourseStatus status;
  final double? average;

  /// Lý do trượt, hiển thị cho sinh viên.
  final String reason;
}

/// Kiểm tra một điểm nhập tay; trả về thông báo lỗi hoặc null nếu hợp lệ.
String? validateMark(String input) {
  final value = double.tryParse(input.trim().replaceAll(',', '.'));
  if (value == null) return 'Nhập số từ 0 đến 10';
  if (value < 0 || value > 10) return 'Điểm phải trong khoảng 0 – 10';
  return null;
}

/// Điểm trung bình có trọng số, làm tròn 1 chữ số. Null nếu còn đầu điểm
/// chưa nhập.
double? weightedAverage(Subject subject, Map<String, double> marks) {
  var sum = 0.0;
  for (final c in subject.components) {
    final mark = marks[c.name];
    if (mark == null) return null;
    sum += mark * c.weight;
  }
  return (sum / 100 * 10).round() / 10;
}

/// Đủ tất cả đầu điểm thì mới được gửi duyệt.
bool isComplete(Subject subject, Map<String, double> marks) =>
    subject.components.every((c) => marks.containsKey(c.name));

/// Kết quả môn học của một sinh viên.
///
/// - Chưa công bố → Đang học.
/// - Vắng quá 20% → Not passed dù điểm đủ.
/// - Bài thi cuối kỳ < 4 hoặc trung bình < 5 → Not passed.
CourseResult evaluate(
  Subject subject,
  Map<String, double> marks, {
  required bool published,
  required bool attendanceBanned,
}) {
  if (!published) return const CourseResult(CourseStatus.studying);
  final average = weightedAverage(subject, marks);
  if (attendanceBanned) {
    return CourseResult(
      CourseStatus.notPassed,
      average: average,
      reason: 'Vắng quá 20% số buổi',
    );
  }
  if (average == null) return const CourseResult(CourseStatus.studying);
  for (final c in subject.components.where((c) => c.isFinal)) {
    if (marks[c.name]! < minFinalMark) {
      return CourseResult(
        CourseStatus.notPassed,
        average: average,
        reason: '${c.name} dưới $minFinalMark',
      );
    }
  }
  if (average < minAverage) {
    return CourseResult(
      CourseStatus.notPassed,
      average: average,
      reason: 'Điểm trung bình dưới $minAverage',
    );
  }
  return CourseResult(CourseStatus.passed, average: average);
}
