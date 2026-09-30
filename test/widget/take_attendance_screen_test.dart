import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/constants.dart';
import 'package:myfap/data/models/app_user.dart';
import 'package:myfap/data/models/class_session.dart';
import 'package:myfap/data/repositories/academic_repository.dart';
import 'package:myfap/data/repositories/user_repository.dart';
import 'package:myfap/views/lecturer/take_attendance_screen.dart';
import 'package:provider/provider.dart';

Future<ClassSession> _seed(FakeFirebaseFirestore db, DateTime date) async {
  for (final (uid, name, code) in [
    ('an', 'Lê Minh An', 'HE170001'),
    ('ha', 'Trần Thu Hà', 'HE170002'),
  ]) {
    await db
        .collection(Collections.users)
        .doc(uid)
        .set(
          AppUser(
            uid: uid,
            role: UserRole.student,
            fullName: name,
            code: code,
            email: '$code@myfap.vn',
          ).toMap(),
        );
  }
  final session = ClassSession(
    id: 's1',
    classId: 'c1',
    classCode: 'SE1943',
    subjectCode: 'PRM393',
    sessionNo: 1,
    date: date,
    slot: 1,
    room: 'BE-301',
    studentIds: const ['an', 'ha'],
    lecturerId: 'son',
    lecturerName: 'sonnt5',
  );
  await db.collection(Collections.sessions).doc('s1').set(session.toMap());
  return session;
}

Widget _app(FakeFirebaseFirestore db, ClassSession session) => MultiProvider(
  providers: [
    Provider(create: (_) => AcademicRepository(db)),
    Provider(create: (_) => UserRepository(db)),
  ],
  child: MaterialApp(home: TakeAttendanceScreen(session: session)),
);

void main() {
  testWidgets('Giảng viên đánh vắng một sinh viên rồi lưu điểm danh', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final session = await _seed(db, DateUtils.dateOnly(DateTime.now()));
    await tester.pumpWidget(_app(db, session));
    await tester.pumpAndSettle();

    expect(find.text('Lê Minh An'), findsOneWidget);
    expect(find.text('0/2 sinh viên'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Trần Thu Hà'));
    await tester.pump();
    expect(find.text('1/2 sinh viên'), findsOneWidget);

    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();

    final saved = await db.collection(Collections.sessions).doc('s1').get();
    expect(saved.data()!['attendance'], {'an': 'present', 'ha': 'absent'});
  });

  testWidgets('Buổi học ngày mai: chỉ xem, SV hiện "Chưa diễn ra"', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final tomorrow = DateUtils.dateOnly(DateTime.now())
        .add(const Duration(days: 1));
    final session = await _seed(db, tomorrow);
    await tester.pumpWidget(_app(db, session));
    await tester.pumpAndSettle();

    expect(find.textContaining('chưa điểm danh được'), findsOneWidget);
    expect(find.text('Lưu điểm danh'), findsNothing);
    // Trước đây mặc định hiện "Có mặt" cho buổi chưa diễn ra.
    expect(find.text('Chưa diễn ra'), findsNWidgets(2));
    expect(find.text('Có mặt'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });
}
