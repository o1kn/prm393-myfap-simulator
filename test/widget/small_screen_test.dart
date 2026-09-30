import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/constants.dart';
import 'package:myfap/data/models/app_user.dart';
import 'package:myfap/data/models/course_class.dart';
import 'package:myfap/data/models/grade_record.dart';
import 'package:myfap/data/models/subject.dart';
import 'package:myfap/data/repositories/academic_repository.dart';
import 'package:myfap/data/repositories/application_repository.dart';
import 'package:myfap/data/repositories/grade_repository.dart';
import 'package:myfap/data/repositories/notification_repository.dart';
import 'package:myfap/data/repositories/user_repository.dart';
import 'package:myfap/views/applications_screen.dart';
import 'package:myfap/views/class_list_screen.dart';
import 'package:myfap/views/grade_sheet_screen.dart';
import 'package:myfap/views/lecturer/take_attendance_screen.dart';
import 'package:myfap/views/notifications_screen.dart';
import 'package:myfap/views/staff/class_detail_screen.dart';
import 'package:myfap/views/staff/staff_accounts_screen.dart';
import 'package:myfap/views/student/attendance_report_screen.dart';
import 'package:myfap/views/student/grade_report_screen.dart';
import 'package:myfap/views/student/transcript_screen.dart';
import 'package:myfap/views/timetable_screen.dart';
import 'package:myfap/views/widgets/common.dart';
import 'package:provider/provider.dart';

/// Màn hình 320dp (điện thoại nhỏ) + chữ phóng to 2x: không màn nào được tràn
/// bố cục (RenderFlex overflow) hay ném lỗi khi dựng.
const _student = AppUser(
  uid: 'an',
  role: UserRole.student,
  fullName: 'Lê Minh An',
  code: 'HE170001',
  email: 'he170001@myfap.vn',
);

const _lecturer = AppUser(
  uid: 'son',
  role: UserRole.lecturer,
  fullName: 'Ngô Tùng Sơn',
  code: 'sonnt5',
  email: 'sonnt@myfap.vn',
  department: 'SE',
);

const _staff = AppUser(
  uid: 'staff',
  role: UserRole.staff,
  fullName: 'Nguyễn Thị Hoa',
  code: 'hoant',
  email: 'daotao@myfap.vn',
);

const _subject = Subject(
  code: 'PRM393',
  name: 'Mobile Programming',
  credits: 3,
  department: 'SE',
  totalSessions: 4,
  components: [
    GradeComponent(name: 'Assignment', weight: 20),
    GradeComponent(name: 'Progress Test', weight: 20),
    GradeComponent(name: 'Project', weight: 30),
    GradeComponent(name: 'Final Exam', weight: 30, isFinal: true),
  ],
);

void main() {
  late FakeFirebaseFirestore db;
  late AcademicRepository academic;
  late GradeRepository grades;
  late UserRepository users;
  late CourseClass course;

  setUp(() async {
    db = FakeFirebaseFirestore();
    academic = AcademicRepository(db);
    grades = GradeRepository(db);
    users = UserRepository(db);
    for (final u in [_student, _lecturer, _staff]) {
      await db.collection(Collections.users).doc(u.uid).set(u.toMap());
    }
    await db.collection(Collections.subjects).doc(_subject.code).set(
      _subject.toMap(),
    );
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day - today.weekday + 1);
    await academic.createClassWithSchedule(
      subject: _subject,
      classCode: 'se1943',
      studentIds: [_student.uid],
      startDate: DateTime(monday.year, monday.month, monday.day - 7),
      weekdays: {DateTime.monday, DateTime.thursday},
      slot: 1,
      room: 'BE-301',
    );
    course = (await academic.allClasses()).single;
    await academic.assignLecturer(course, _lecturer);
    course = await academic.classById(course.id);
    await grades.saveGrades(course, [
      GradeRecord(
        classId: course.id,
        studentId: _student.uid,
        studentName: _student.fullName,
        studentCode: _student.code,
        subjectCode: course.subjectCode,
        semester: currentSemester,
        marks: const {'Assignment': 8, 'Project': 9, 'Final Exam': 7},
        published: true,
      ),
    ], submit: false);
    await db.collection(Collections.notifications).doc('n1').set({
      'title': 'Lịch thi Progress Test kỳ Fall2026',
      'content': 'Sinh viên xem lịch thi Progress Test trên myFAP từ tuần sau.',
      'audience': 'students',
      'createdAt': DateTime(2026, 9, 28).toIso8601String(),
      'authorName': _staff.fullName,
    });
    await db.collection(Collections.applications).doc('a1').set({
      'studentId': _student.uid,
      'studentName': _student.fullName,
      'studentCode': _student.code,
      'type': 'Xác nhận sinh viên',
      'content': 'Xin giấy xác nhận sinh viên để làm thẻ xe bus.',
      'createdAt': DateTime(2026, 9, 29).toIso8601String(),
      'status': 'processing',
      'staffNote': '',
      'processedBy': '',
      'processedAt': null,
    });
  });

  /// Điện thoại nhỏ: 320x640 điểm ảnh logic, chữ 2x.
  Future<void> pumpSmall(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AcademicRepository>.value(value: academic),
          Provider<GradeRepository>.value(value: grades),
          Provider<UserRepository>.value(value: users),
          Provider<ApplicationRepository>.value(
            value: ApplicationRepository(db),
          ),
          Provider<NotificationRepository>.value(
            value: NotificationRepository(db),
          ),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expectNoOverflow(WidgetTester tester) async {
    final error = tester.takeException();
    expect(
      error,
      isNull,
      reason: 'Màn hình tràn bố cục hoặc lỗi khi dựng: $error',
    );
  }

  final screens = <String, Widget Function()>{
    'Lịch học sinh viên': () => const TimetableScreen(user: _student),
    'Điểm danh sinh viên': () => const AttendanceReportScreen(student: _student),
    'Điểm học kỳ sinh viên': () => const GradeReportScreen(student: _student),
    'Bảng điểm sinh viên': () => const TranscriptScreen(student: _student),
    'Thông báo': () => const NotificationsScreen(user: _student),
    'Đơn từ sinh viên': () => const ApplicationsScreen(user: _student),
    'Lịch dạy giảng viên': () => const TimetableScreen(user: _lecturer),
    'Danh sách lớp nhập điểm': () => const ClassListScreen(user: _lecturer),
    'Chi tiết lớp': () => ClassDetailScreen(classId: course.id),
    'Quản lý tài khoản': () => const StaffAccountsScreen(),
    'Đơn từ cán bộ ĐT': () => const ApplicationsScreen(user: _staff),
  };

  screens.forEach((name, build) {
    testWidgets('$name: 320dp + chữ 2x không tràn bố cục', (tester) async {
      await pumpSmall(tester, build());
      await expectNoOverflow(tester);
    });
  });

  testWidgets('Bảng điểm: 320dp + chữ 2x không tràn bố cục', (tester) async {
    await pumpSmall(
      tester,
      GradeSheetScreen(course: course, viewer: _lecturer),
    );
    await expectNoOverflow(tester);
  });

  testWidgets('Buổi học tương lai: 320dp + chữ 2x không tràn bố cục', (
    tester,
  ) async {
    final sessions = await academic.sessionsOfClass(course.id);
    final future = sessions.firstWhere(
      (s) => s.date.isAfter(DateTime.now()),
    );
    await pumpSmall(tester, TakeAttendanceScreen(session: future));
    await expectNoOverflow(tester);
  });

  // Hàng ô số liệu ở trang chủ: nhãn dài, trước đây bị cắt thành "Buổi học h…"
  // trên máy nhỏ khi chữ phóng to.
  const tiles = StatRow([
    StatTile(value: '1', label: 'Buổi học hôm nay'),
    StatTile(value: '0', label: 'Đơn đang xử lý'),
  ]);

  testWidgets('Hàng số liệu: chữ 2x thì xếp dọc và không cắt nhãn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: tiles)),
    );

    for (final label in ['Buổi học hôm nay', 'Đơn đang xử lý']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Nhãn "$label" bị cắt bằng dấu ...',
      );
    }
    final first = tester.getCenter(find.text('Buổi học hôm nay'));
    final second = tester.getCenter(find.text('Đơn đang xử lý'));
    expect(second.dy, greaterThan(first.dy), reason: 'Hai ô phải xếp dọc');
  });

  testWidgets('Hàng số liệu: máy thường, chữ 1x thì vẫn xếp ngang', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: tiles)),
    );

    final first = tester.getCenter(find.text('Buổi học hôm nay'));
    final second = tester.getCenter(find.text('Đơn đang xử lý'));
    expect(second.dx, greaterThan(first.dx));
    expect(second.dy, first.dy);
  });
}