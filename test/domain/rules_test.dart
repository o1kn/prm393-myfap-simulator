import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/data/models/class_session.dart';
import 'package:myfap/data/models/subject.dart';
import 'package:myfap/domain/attendance_rules.dart';
import 'package:myfap/domain/grade_rules.dart';
import 'package:myfap/domain/schedule_rules.dart';

ClassSession _session(
  int no, {
  DateTime? date,
  int slot = 1,
  String room = 'BE-301',
  Map<String, AttendanceStatus> attendance = const {},
}) => ClassSession(
  id: 's$no',
  classId: 'c1',
  classCode: 'SE1943',
  subjectCode: 'PRM393',
  sessionNo: no,
  date: date ?? DateTime(2026, 9, no),
  slot: slot,
  room: room,
  studentIds: const ['u1'],
  attendance: attendance,
);

const _subject = Subject(
  code: 'PRM393',
  name: 'Mobile Programming',
  credits: 3,
  department: 'SE',
  totalSessions: 20,
  components: [
    GradeComponent(name: 'Assignment', weight: 20),
    GradeComponent(name: 'Progress Test', weight: 20),
    GradeComponent(name: 'Project', weight: 30),
    GradeComponent(name: 'Final Exam', weight: 30, isFinal: true),
  ],
);

Map<String, double> _marks(double a, double p, double pr, double fe) => {
  'Assignment': a,
  'Progress Test': p,
  'Project': pr,
  'Final Exam': fe,
};

void main() {
  group('Điểm danh', () {
    List<ClassSession> sessions(int absent) => [
      for (var i = 1; i <= 20; i++)
        _session(
          i,
          attendance: i <= absent ? {'u1': AttendanceStatus.absent} : const {},
        ),
    ];

    test('vắng đúng 20% vẫn đủ điều kiện dự thi, vắng 5/20 thì bị cấm thi', () {
      expect(AttendanceSummary.of(sessions(4), 'u1').isBanned, isFalse);
      expect(AttendanceSummary.of(sessions(5), 'u1').isBanned, isTrue);
    });

    test('buổi chưa diễn ra không tính là vắng', () {
      final summary = AttendanceSummary.of(sessions(2), 'u1');
      expect(summary.absent, 2);
      expect(summary.notYet, 18);
    });

    test('không điểm danh trước ngày học, được điểm danh trong ngày', () {
      final s = _session(1, date: DateTime(2026, 9, 30));
      expect(canTakeAttendance(s, DateTime(2026, 9, 29, 23)), isFalse);
      expect(canTakeAttendance(s, DateTime(2026, 9, 30, 7)), isTrue);
    });
  });

  group('Kết quả môn học', () {
    test('trung bình có trọng số, thiếu đầu điểm thì chưa tính', () {
      expect(weightedAverage(_subject, _marks(8, 7, 9, 6)), 7.5);
      expect(weightedAverage(_subject, {'Assignment': 8}), isNull);
    });

    test('chưa công bố thì là Đang học', () {
      final r = evaluate(
        _subject,
        _marks(9, 9, 9, 9),
        published: false,
        attendanceBanned: false,
      );
      expect(r.status, CourseStatus.studying);
    });

    test('Final Exam dưới 4 thì trượt dù trung bình trên 5', () {
      final r = evaluate(
        _subject,
        _marks(9, 9, 9, 3.5),
        published: true,
        attendanceBanned: false,
      );
      expect(r.average, greaterThanOrEqualTo(minAverage));
      expect(r.status, CourseStatus.notPassed);
    });

    test('vắng quá 20% thì trượt dù điểm cao', () {
      final r = evaluate(
        _subject,
        _marks(9, 9, 9, 9),
        published: true,
        attendanceBanned: true,
      );
      expect(r.status, CourseStatus.notPassed);
    });

    test('đạt khi trung bình ≥ 5 và Final Exam ≥ 4', () {
      final r = evaluate(
        _subject,
        _marks(5, 5, 5, 4),
        published: true,
        attendanceBanned: false,
      );
      expect(r.status, CourseStatus.notPassed);
      final ok = evaluate(
        _subject,
        _marks(7, 6, 5, 4),
        published: true,
        attendanceBanned: false,
      );
      expect(ok.status, CourseStatus.passed);
    });

    test('điểm nhập tay phải trong 0..10', () {
      expect(validateMark('10'), isNull);
      expect(validateMark('7,5'), isNull);
      expect(validateMark('10.5'), isNotNull);
      expect(validateMark('abc'), isNotNull);
    });
  });

  group('Xếp lịch', () {
    test('sinh đủ số buổi đúng thứ trong tuần', () {
      final dates = generateStudyDates(DateTime(2026, 9, 28), {1, 4}, 4);
      expect(dates, [
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 8),
      ]);
    });

    test(
      'trùng phòng cùng slot cùng ngày là xung đột, khác slot thì không',
      () {
        final existing = [_session(1, date: DateTime(2026, 10, 1))];
        expect(
          findRoomConflicts([
            _session(9, date: DateTime(2026, 10, 1)),
          ], existing),
          hasLength(1),
        );
        expect(
          findRoomConflicts([
            _session(9, date: DateTime(2026, 10, 1), slot: 2),
          ], existing),
          isEmpty,
        );
      },
    );
  });
}
