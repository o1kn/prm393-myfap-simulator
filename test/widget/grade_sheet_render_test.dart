import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/constants.dart';
import 'package:myfap/data/models/app_user.dart';
import 'package:myfap/data/models/subject.dart';
import 'package:myfap/data/repositories/academic_repository.dart';
import 'package:myfap/data/repositories/grade_repository.dart';
import 'package:myfap/data/repositories/user_repository.dart';
import 'package:myfap/views/grade_sheet_screen.dart';
import 'package:provider/provider.dart';

const _an = AppUser(
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
  testWidgets('Màn bảng điểm hiện tên sinh viên và ô điểm', (tester) async {
    final db = FakeFirebaseFirestore();
    final academic = AcademicRepository(db);
    final users = UserRepository(db);
    for (final u in [_an, _lecturer]) {
      await db.collection(Collections.users).doc(u.uid).set(u.toMap());
    }
    await db.collection(Collections.subjects).doc(_prm.code).set(_prm.toMap());
    await academic.createClassWithSchedule(
      subject: _prm,
      classCode: 'se1943',
      studentIds: [_an.uid],
      startDate: DateTime(2026, 9, 28),
      weekdays: {DateTime.monday},
      slot: 1,
      room: 'BE-301',
    );
    final course = (await academic.allClasses()).single;
    // Giảng viên chỉ mở được bảng điểm lớp mình dạy.
    await academic.assignLecturer(course, _lecturer);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AcademicRepository>.value(value: academic),
          Provider<GradeRepository>.value(value: GradeRepository(db)),
          Provider<UserRepository>.value(value: users),
        ],
        child: MaterialApp(
          home: GradeSheetScreen(course: course, viewer: _lecturer),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Lê Minh An'), findsOneWidget);
    expect(find.text('HE170001'), findsOneWidget);
  });
}
