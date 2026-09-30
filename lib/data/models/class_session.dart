import 'package:intl/intl.dart';

import '../../core/constants.dart';

/// Trạng thái điểm danh một buổi, đúng 3 giá trị của myFAP gốc.
enum AttendanceStatus {
  present('Có mặt'),
  absent('Vắng'),
  notYet('Chưa diễn ra');

  const AttendanceStatus(this.label);

  final String label;
}

final _dateKey = DateFormat('yyyy-MM-dd');

/// Một buổi học của lớp môn, document `sessions/{id}`. Điểm danh lưu ngay
/// trong buổi học (map mã sinh viên → trạng thái).
class ClassSession {
  const ClassSession({
    required this.id,
    required this.classId,
    required this.classCode,
    required this.subjectCode,
    required this.sessionNo,
    required this.date,
    required this.slot,
    required this.room,
    required this.studentIds,
    this.lecturerId,
    this.lecturerName,
    this.attendance = const {},
  });

  final String id;
  final String classId;
  final String classCode;
  final String subjectCode;

  /// Buổi thứ mấy của lớp (1..totalSessions).
  final int sessionNo;

  /// Ngày học (không có giờ); giờ học suy ra từ [slot].
  final DateTime date;
  final int slot;
  final String room;

  /// Sao chép từ lớp để sinh viên truy vấn lịch bằng `array-contains`.
  final List<String> studentIds;
  final String? lecturerId;
  final String? lecturerName;

  /// uid sinh viên → `present` / `absent`. Rỗng = chưa điểm danh.
  final Map<String, AttendanceStatus> attendance;

  bool get taken => attendance.isNotEmpty;

  String get slotTime => slotTimes[slot] ?? '';

  String get dateKey => _dateKey.format(date);

  AttendanceStatus statusOf(String studentId) =>
      attendance[studentId] ?? AttendanceStatus.notYet;

  static DateTime parseDateKey(String key) => _dateKey.parseStrict(key);

  static String formatDateKey(DateTime date) => _dateKey.format(date);

  factory ClassSession.fromMap(String id, Map<String, dynamic> map) =>
      ClassSession(
        id: id,
        classId: map['classId'] as String,
        classCode: map['classCode'] as String,
        subjectCode: map['subjectCode'] as String,
        sessionNo: (map['sessionNo'] as num).toInt(),
        date: parseDateKey(map['date'] as String),
        slot: (map['slot'] as num).toInt(),
        room: map['room'] as String,
        studentIds: List<String>.from(map['studentIds'] as List),
        lecturerId: map['lecturerId'] as String?,
        lecturerName: map['lecturerName'] as String?,
        attendance: {
          for (final e in Map<String, dynamic>.from(
            map['attendance'] as Map? ?? const {},
          ).entries)
            e.key: AttendanceStatus.values.byName(e.value as String),
        },
      );

  Map<String, dynamic> toMap() => {
    'classId': classId,
    'classCode': classCode,
    'subjectCode': subjectCode,
    'sessionNo': sessionNo,
    'date': dateKey,
    'slot': slot,
    'room': room,
    'studentIds': studentIds,
    'lecturerId': lecturerId,
    'lecturerName': lecturerName,
    'attendance': {for (final e in attendance.entries) e.key: e.value.name},
  };
}
