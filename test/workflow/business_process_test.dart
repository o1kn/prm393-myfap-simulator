import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/constants.dart';
import 'package:myfap/data/models/app_user.dart';
import 'package:myfap/data/models/application_form.dart';
import 'package:myfap/data/models/class_session.dart';
import 'package:myfap/data/models/course_class.dart';
import 'package:myfap/data/models/subject.dart';
import 'package:myfap/data/repositories/academic_repository.dart';
import 'package:myfap/data/repositories/application_repository.dart';
import 'package:myfap/data/repositories/grade_repository.dart';
import 'package:myfap/data/repositories/user_repository.dart';
import 'package:myfap/domain/grade_rules.dart';
import 'package:myfap/viewmodels/applications_view_model.dart';
import 'package:myfap/viewmodels/grade_sheet_view_model.dart';
import 'package:myfap/viewmodels/head/assignment_view_model.dart';
import 'package:myfap/viewmodels/lecturer/take_attendance_view_model.dart';
import 'package:myfap/viewmodels/student/results_view_model.dart';

const staff = AppUser(
  uid: 'staff',
  role: UserRole.staff,
  fullName: 'Nguyễn Thị Hoa',
  code: 'hoant',
  email: 'daotao@myfap.vn',
);
const head = AppUser(
  uid: 'head',
  role: UserRole.head,
  fullName: 'Trần Văn Nam',
  code: 'namtv',
  email: 'truongbm.se@myfap.vn',
  department: 'SE',
);
const lecturer = AppUser(
  uid: 'son',
  role: UserRole.lecturer,
  fullName: 'Ngô Tùng Sơn',
  code: 'sonnt5',
  email: 'sonnt@myfap.vn',
  department: 'SE',
);
const aiLecturer = AppUser(
  uid: 'hung',
  role: UserRole.lecturer,
  fullName: 'Lê Văn Hùng',
  code: 'hunglv',
  email: 'hunglv@myfap.vn',
  department: 'AI',
);
const an = AppUser(
  uid: 'an',
  role: UserRole.student,
  fullName: 'Lê Minh An',
  code: 'HE170001',
  email: 'he170001@myfap.vn',
);
const ha = AppUser(
  uid: 'ha',
  role: UserRole.student,
  fullName: 'Trần Thu Hà',
  code: 'HE170002',
  email: 'he170002@myfap.vn',
);

const prm = Subject(
  code: 'PRM393',
  name: 'Mobile Programming',
  credits: 3,
  department: 'SE',
  totalSessions: 4,
  components: [
    GradeComponent(name: 'Assignment', weight: 40),
    GradeComponent(name: 'Final Exam', weight: 60, isFinal: true),
  ],
);

void main() {
  late FakeFirebaseFirestore db;
  late AcademicRepository academic;
  late GradeRepository grades;
  late UserRepository users;

  setUp(() async {
    db = FakeFirebaseFirestore();
    academic = AcademicRepository(db);
    grades = GradeRepository(db);
    users = UserRepository(db);
    for (final u in [staff, head, lecturer, aiLecturer, an, ha]) {
      await db.collection(Collections.users).doc(u.uid).set(u.toMap());
    }
    await db.collection(Collections.subjects).doc(prm.code).set(prm.toMap());
  });

  Future<CourseClass> openClass({String room = 'BE-301'}) async {
    await academic.createClassWithSchedule(
      subject: prm,
      classCode: 'se1943',
      studentIds: [an.uid, ha.uid],
      startDate: DateTime(2026, 9, 28),
      weekdays: {DateTime.monday, DateTime.thursday},
      slot: 1,
      room: room,
    );
    return (await academic.allClasses()).single;
  }

  test(
    'Cán bộ ĐT mở lớp: sinh đủ buổi học, chặn trùng mã lớp và trùng phòng',
    () async {
      final course = await openClass();
      expect(course.code, 'SE1943');
      expect(course.lecturerId, isNull);
      final sessions = await academic.sessionsOfClass(course.id);
      expect(sessions.map((s) => s.dateKey), [
        '2026-09-28',
        '2026-10-01',
        '2026-10-05',
        '2026-10-08',
      ]);
      // Sinh viên thấy lịch học ngay sau khi lớp được mở.
      expect(await academic.sessionsOfStudent(an.uid), hasLength(4));

      await expectLater(openClass(room: 'BE-999'), throwsA(anything));
      await expectLater(
        academic.createClassWithSchedule(
          subject: prm,
          classCode: 'SE1999',
          studentIds: [an.uid],
          startDate: DateTime(2026, 9, 28),
          weekdays: {DateTime.monday},
          slot: 1,
          room: 'be-301',
        ),
        throwsA(predicate((e) => e.toString().contains('Phòng BE-301 slot 1'))),
      );
    },
  );

  test(
    'Quy trình đầy đủ: phân công → điểm danh → nhập điểm → duyệt → SV xem',
    () async {
      var course = await openClass();

      // 1. Trưởng BM SE không phân công được GV bộ môn AI.
      final assignment = AssignmentViewModel(academic, users, head);
      await assignment.load();
      expect(assignment.lecturers.map((l) => l.uid), [lecturer.uid]);
      expect(await assignment.assign(course, aiLecturer), isFalse);
      expect(assignment.error, contains('không thuộc bộ môn'));

      expect(await assignment.assign(course, lecturer), isTrue);
      final lecturerSessions = await academic.sessionsOfLecturer(lecturer.uid);
      expect(lecturerSessions, hasLength(4));
      expect(lecturerSessions.first.lecturerName, 'sonnt5');

      // 2. Giảng viên điểm danh buổi 1: Hà vắng. Buổi tương lai bị chặn.
      final first = lecturerSessions.first;
      final attendance = TakeAttendanceViewModel(
        academic,
        users,
        first,
        clock: () => DateTime(2026, 9, 28, 8),
      );
      await attendance.load();
      attendance.toggle(ha.uid);
      expect(await attendance.save(), isTrue);
      final saved = (await academic.sessionsOfStudent(ha.uid)).first;
      expect(saved.statusOf(ha.uid), AttendanceStatus.absent);
      expect(saved.statusOf(an.uid), AttendanceStatus.present);

      final future = TakeAttendanceViewModel(
        academic,
        users,
        lecturerSessions.last,
        clock: () => DateTime(2026, 9, 28, 8),
      );
      await future.load();
      expect(future.editable, isFalse);
      expect(await future.save(), isFalse);

      // 3. Giảng viên nhập điểm: gửi khi còn thiếu điểm bị từ chối.
      course = await academic.classById(course.id);
      final sheet = GradeSheetViewModel(academic, grades, users, course);
      await sheet.load();
      expect(sheet.setMark(an.uid, 'Assignment', '11'), isNotNull);
      // Ô lỗi chặn cả lưu nháp: không ghi gì xuống Firestore.
      expect(await sheet.saveDraft(), isFalse);
      expect(sheet.error, contains('không hợp lệ'));
      expect(await grades.gradesOfClass(course.id), isEmpty);
      sheet
        ..setMark(an.uid, 'Assignment', '8')
        ..setMark(an.uid, 'Final Exam', '7');
      expect(await sheet.submit(), isFalse);
      expect(sheet.error, contains('1 sinh viên'));

      sheet
        ..setMark(ha.uid, 'Assignment', '9')
        ..setMark(ha.uid, 'Final Exam', '3');
      expect(await sheet.submit(), isTrue);
      expect(sheet.course.gradeStatus, GradeStatus.submitted);
      expect(sheet.editable, isFalse);

      // Chưa công bố: sinh viên chưa thấy điểm.
      final before = ResultsViewModel(academic, grades, an);
      await before.load();
      expect(before.rows.single.result.status, CourseStatus.studying);

      // 4. Trưởng BM trả lại → GV sửa được lại → gửi lại → công bố.
      final review = GradeSheetViewModel(academic, grades, users, course);
      await review.load();
      expect(await review.returnToLecturer(''), isFalse);
      expect(await review.returnToLecturer('Kiểm tra lại điểm Hà'), isTrue);
      await sheet.load();
      expect(sheet.editable, isTrue);
      expect(await sheet.submit(), isTrue);

      await review.load();
      expect(await review.publish(), isTrue);
      expect(review.course.gradeStatus, GradeStatus.published);

      // 5. Sinh viên xem kết quả.
      final resultAn = ResultsViewModel(academic, grades, an);
      await resultAn.load();
      expect(resultAn.rows.single.result.status, CourseStatus.passed);
      expect(resultAn.rows.single.result.average, 7.4);
      expect(resultAn.passedCredits, 3);

      // Hà vắng 1/4 buổi (25%) ở bước 2 → trượt vì điểm danh, dù đã có điểm.
      final resultHa = ResultsViewModel(academic, grades, ha);
      await resultHa.load();
      expect(resultHa.rows.single.result.status, CourseStatus.notPassed);
      expect(resultHa.rows.single.result.reason, contains('Vắng quá 20%'));
    },
  );

  test('Đơn từ: SV gửi → cán bộ ĐT xử lý; từ chối phải có lý do', () async {
    final repo = ApplicationRepository(db);
    final student = ApplicationsViewModel(repo, an);
    expect(await student.submit(applicationTypes.first, 'ngắn'), isFalse);
    expect(
      await student.submit(
        applicationTypes.first,
        'Em xin chuyển sang lớp SE1944 vì trùng lịch.',
      ),
      isTrue,
    );
    expect(student.items.single.status, ApplicationStatus.processing);

    final office = ApplicationsViewModel(repo, staff);
    await office.load();
    expect(office.pendingCount, 1);
    final form = office.items.single;
    expect(
      await office.process(form, ApplicationStatus.rejected, ' '),
      isFalse,
    );
    expect(
      await office.process(form, ApplicationStatus.approved, 'Đã chuyển lớp'),
      isTrue,
    );
    expect(
      await office.process(form, ApplicationStatus.rejected, 'Lý do'),
      isFalse,
    );

    await student.load();
    expect(student.items.single.status, ApplicationStatus.approved);
    expect(student.items.single.processedBy, staff.fullName);
  });
}
