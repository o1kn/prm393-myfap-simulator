import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/constants.dart';
import 'package:myfap/data/models/app_user.dart';
import 'package:myfap/data/repositories/application_repository.dart';
import 'package:myfap/views/applications_screen.dart';
import 'package:provider/provider.dart';

const _student = AppUser(
  uid: 'an',
  role: UserRole.student,
  fullName: 'Lê Minh An',
  code: 'HE170001',
  email: 'he170001@myfap.vn',
);

void main() {
  testWidgets('Đơn quá ngắn: lỗi hiện trong sheet, không bị lớp modal che', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(
      Provider(
        create: (_) => ApplicationRepository(db),
        child: const MaterialApp(home: ApplicationsScreen(user: _student)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gửi đơn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('application-content')), 'abc');
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();

    // SnackBar của trang nằm dưới sheet nên người dùng không thấy được;
    // lỗi phải nằm trong sheet và bấm/nhìn được.
    expect(
      find.text('Nội dung đơn cần ít nhất 10 ký tự').hitTestable(),
      findsOneWidget,
    );
    final saved = await db.collection(Collections.applications).get();
    expect(saved.docs, isEmpty);
  });
}
