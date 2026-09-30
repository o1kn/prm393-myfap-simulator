import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/constants.dart';
import 'package:myfap/data/models/app_user.dart';
import 'package:myfap/data/models/course_class.dart';
import 'package:myfap/data/models/subject.dart';
import 'package:myfap/data/repositories/academic_repository.dart';
import 'package:myfap/data/repositories/grade_repository.dart';
import 'package:myfap/data/repositories/user_repository.dart';
import 'package:myfap/viewmodels/grade_sheet_view_model.dart';
import 'package:myfap/viewmodels/lecturer/take_attendance_view_model.dart';

const _an = AppUser(
  uid: 'an',
  role: UserRole.student,
  fullName: 'Lê Minh An',
  code: 'HE170001',
  email: 'he170001@myfap.vn',
);
const _ha = AppUser(
  uid: 'ha',
  role: UserRole.student,
  fullName: 'Trần Thu Hà',
  code: 'HE170002',
  email: 'he170002@myfap.vn',
);

const _lecturer = AppUser(
  uid: 'son',
  role: UserRole.lecturer,
  fullName: 'Ngô Tùng Sơn',
  code: 'sonnt5',
  email: 'sonnt@myfap.vn',
  department: 'SE',
);

const _prm = Subject(
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
    for (final u in [_an, _ha, _lecturer]) {
      await db.collection(Collections.users).doc(u.uid).set(u.toMap());
    }
    await db.collection(Collections.subjects).doc(_prm.code).set(_prm.toMap());
    await academic.createClassWithSchedule(
      subject: _prm,
      classCode: 'se1943',
      studentIds: [_an.uid, _ha.uid],
      startDate: DateTime(2026, 9, 28),
      weekdays: {DateTime.monday, DateTime.thursday},
      slot: 1,
      room: 'BE-301',
    );
    // Lớp có giảng viên: bảng điểm luôn được mở từ lớp của chính giảng viên.
    await academic.assignLecturer(
      (await academic.allClasses()).single,
      _lecturer,
    );
  });

  Future<CourseClass> openCourse() async =>
      (await academic.allClasses()).single;

  test('Bảng điểm: ô sai cũng tính bẩn, lưu hỏng giữ bẩn, lưu xong hết bẩn', () async {
    final sheet = GradeSheetViewModel(
      academic,
      grades,
      users,
      await openCourse(),
      _lecturer,
    );
    await sheet.load();
    expect(sheet.hasUnsavedChanges, isFalse);

    // Ô nhập sai không ghi đè điểm nhưng vẫn tính là thay đổi chưa lưu.
    expect(sheet.setMark(_an.uid, 'Assignment', '11'), isNotNull);
    expect(sheet.hasUnsavedChanges, isTrue);
    expect(await sheet.saveDraft(), isFalse);
    expect(sheet.hasUnsavedChanges, isTrue);

    sheet.setMark(_an.uid, 'Assignment', '8');
    expect(sheet.hasUnsavedChanges, isTrue);
    expect(await sheet.saveDraft(), isTrue);
    expect(sheet.hasUnsavedChanges, isFalse);

    // Nhập lại đúng giá trị đã lưu thì không còn vết bẩn.
    sheet.setMark(_an.uid, 'Assignment', '8');
    expect(sheet.hasUnsavedChanges, isFalse);
  });

  test('Bảng điểm: sinh viên vào muộn không gánh buổi cũ', () async {
    final course = await openCourse();
    final sessions = await academic.sessionsOfClass(course.id);
    expect(sessions, hasLength(4));
    await db
        .collection(Collections.sessions)
        .doc(sessions.first.id)
        .update({
          'studentIds': [_an.uid],
        });

    final sheet = GradeSheetViewModel(
      academic, grades, users, course, _lecturer);
    await sheet.load();
    expect(sheet.summaryOf(_an.uid).total, 4);
    expect(sheet.summaryOf(_ha.uid).total, 3);
  });

  test('Điểm danh: đổi chọn thì bẩn, lưu xong hết bẩn, lớp công bố thì khóa', () async {
    final course = await openCourse();
    final sessions = await academic.sessionsOfClass(course.id);
    final first = sessions.firstWhere((s) => s.dateKey == '2026-09-28');

    final vm = TakeAttendanceViewModel(
      academic,
      users,
      first,
      clock: () => DateTime(2026, 9, 28, 8),
    );
    await vm.load();
    expect(vm.hasUnsavedChanges, isFalse);

    vm.toggle(_ha.uid);
    expect(vm.hasUnsavedChanges, isTrue);
    expect(await vm.save(), isTrue);
    expect(vm.hasUnsavedChanges, isFalse);

    // Lớp đã công bố: chỉ xem, lưu bị từ chối.
    await db.collection(Collections.classes).doc(course.id).update({
      'gradeStatus': GradeStatus.published.name,
    });
    final locked = TakeAttendanceViewModel(
      academic,
      users,
      first,
      clock: () => DateTime(2026, 9, 28, 8),
    );
    await locked.load();
    expect(locked.isPublished, isTrue);
    expect(locked.editable, isFalse);
    expect(locked.readonlyReason, contains('công bố'));
    expect(locked.hasUnsavedChanges, isFalse);
    expect(await locked.save(), isFalse);
  });
}
