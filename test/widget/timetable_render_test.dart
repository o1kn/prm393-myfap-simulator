import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/constants.dart';
import 'package:myfap/data/models/app_user.dart';
import 'package:myfap/data/models/subject.dart';
import 'package:myfap/data/repositories/academic_repository.dart';
import 'package:myfap/data/repositories/application_repository.dart';
import 'package:myfap/data/repositories/user_repository.dart';
import 'package:myfap/views/timetable_screen.dart';
import 'package:provider/provider.dart';

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
  totalSessions: 3,
  components: [GradeComponent(name: 'Assignment', weight: 100)],
);

void main() {
  testWidgets('Lịch dạy hiện buổi học của ngày đang chọn', (tester) async {
    final db = FakeFirebaseFirestore();
    final academic = AcademicRepository(db);
    final users = UserRepository(db);
    await db.collection(Collections.users).doc(_lecturer.uid).set(
      _lecturer.toMap(),
    );
    await db.collection(Collections.subjects).doc(_prm.code).set(_prm.toMap());

    // Hôm nay là thứ Tư 30/09/2026 → lớp có buổi đúng hôm nay.
    final today = DateTime(2026, 9, 30);
    await academic.createClassWithSchedule(
      subject: _prm,
      classCode: 'se1943',
      studentIds: [_lecturer.uid],
      startDate: today,
      weekdays: {DateTime.wednesday},
      slot: 1,
      room: 'BE-301',
    );
    final course = (await academic.allClasses()).single;
    await academic.assignLecturer(course, _lecturer);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AcademicRepository>.value(value: academic),
          Provider<ApplicationRepository>.value(
            value: ApplicationRepository(db),
          ),
          Provider<UserRepository>.value(value: users),
        ],
        child: MaterialApp(home: TimetableScreen(user: _lecturer)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PRM393 - SE1943'), findsOneWidget);
  });
}
