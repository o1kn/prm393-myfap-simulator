import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfap/core/constants.dart';
import 'package:myfap/data/models/app_notification.dart';
import 'package:myfap/data/models/app_user.dart';
import 'package:myfap/data/repositories/notification_repository.dart';

/// Thông báo "Tất cả" phải tới được cả sinh viên, giảng viên và trưởng bộ môn;
/// thông báo theo đối tượng chỉ tới đúng nhóm đó (myFAP gốc: tab Messages).
void main() {
  late FakeFirebaseFirestore db;
  late NotificationRepository notifications;

  Future<void> add(String id, Audience audience, String title, int day) =>
      db.collection(Collections.notifications).doc(id).set(
        AppNotification(
          id: id,
          title: title,
          content: 'Nội dung $title',
          audience: audience,
          createdAt: DateTime(2026, 9, day),
          authorName: 'Nguyễn Thị Hoa',
        ).toMap(),
      );

  setUp(() async {
    db = FakeFirebaseFirestore();
    notifications = NotificationRepository(db);
    await add('n1', Audience.all, 'Thông báo chung', 28);
    await add('n2', Audience.students, 'Cho sinh viên', 29);
    await add('n3', Audience.lecturers, 'Cho giảng viên', 30);
  });

  Future<List<String>> titles(UserRole role) async =>
      (await notifications.forRole(role)).map((n) => n.title).toList();

  test('Sinh viên nhận thông báo chung và của sinh viên', () async {
    expect(await titles(UserRole.student), [
      'Cho sinh viên',
      'Thông báo chung',
    ]);
  });

  test('Giảng viên và trưởng bộ môn nhận thông báo chung và của giảng viên',
      () async {
    expect(await titles(UserRole.lecturer), [
      'Cho giảng viên',
      'Thông báo chung',
    ]);
    expect(await titles(UserRole.head), [
      'Cho giảng viên',
      'Thông báo chung',
    ]);
  });

  test('Cán bộ đào tạo thấy mọi thông báo đã đăng', () async {
    expect(await titles(UserRole.staff), [
      'Cho giảng viên',
      'Cho sinh viên',
      'Thông báo chung',
    ]);
  });

  test('Tiêu đề dài quá 200 ký tự bị từ chối trước khi ghi', () async {
    final staff = AppUser(
      uid: 'staff',
      role: UserRole.staff,
      fullName: 'Nguyễn Thị Hoa',
      code: 'hoant',
      email: 'daotao@myfap.vn',
    );
    expect(
      () => notifications.publish(
        author: staff,
        title: 'x' * 201,
        content: 'Nội dung',
        audience: Audience.all,
      ),
      throwsA(isA<Exception>()),
    );
    final snap = await db.collection(Collections.notifications).get();
    expect(snap.docs.length, 3);
  });
}