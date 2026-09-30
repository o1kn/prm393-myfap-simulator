import '../core/constants.dart';
import '../data/models/class_session.dart';

/// Tổng hợp điểm danh của một sinh viên trong một lớp, ví dụ
/// "Vắng 0% (0/10 buổi)".
class AttendanceSummary {
  const AttendanceSummary({
    required this.total,
    required this.present,
    required this.absent,
  });

  factory AttendanceSummary.of(
    Iterable<ClassSession> sessions,
    String studentId,
  ) {
    var present = 0;
    var absent = 0;
    var total = 0;
    for (final s in sessions) {
      total++;
      switch (s.statusOf(studentId)) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.notYet:
          break;
      }
    }
    return AttendanceSummary(total: total, present: present, absent: absent);
  }

  /// Tổng số buổi của lớp (kể cả buổi chưa diễn ra).
  final int total;
  final int present;
  final int absent;

  int get notYet => total - present - absent;

  /// Tỉ lệ vắng tính trên tổng số buổi của lớp.
  double get absentRate => total == 0 ? 0 : absent / total;

  /// Vắng quá 20% tổng số buổi thì không được dự thi.
  bool get isBanned => absentRate > maxAbsentRate;
}

/// Chỉ được điểm danh buổi học đã đến ngày (không điểm danh trước).
bool canTakeAttendance(ClassSession session, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return !session.date.isAfter(today);
}
