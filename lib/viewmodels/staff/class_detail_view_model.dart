import '../../data/models/app_user.dart';
import '../../data/models/class_session.dart';
import '../../data/models/course_class.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../base_view_model.dart';

/// Chi tiết lớp cho cán bộ đào tạo: xem roster + lịch (chỉ đọc) và thêm
/// sinh viên đã có tài khoản. Xem trước số buổi sẽ ghi danh theo cùng luật
/// với repository: buổi chưa tới (`!date.isBefore(today)`) và chưa điểm
/// danh mới được thêm; buổi đã qua / đã điểm danh giữ nguyên.
class ClassDetailViewModel extends BaseViewModel {
  ClassDetailViewModel(this._academic, this._users, this.classId);

  final AcademicRepository _academic;
  final UserRepository _users;
  final String classId;

  CourseClass? course;
  List<ClassSession> sessions = const [];
  List<AppUser> roster = const [];
  List<AppUser> candidates = const [];

  /// Số buổi đã ghi danh thêm ở lần thêm gần nhất (để hiện thông báo).
  int lastAddedSessions = 0;

  /// Sĩ số lấy từ roster của lớp (nguồn sự thật), không suy từ buổi học.
  int get enrolledCount => course?.studentIds.length ?? 0;

  /// Mã sinh viên trong roster nhưng thiếu hồ sơ users (dữ liệu lệch).
  int get missingProfiles => enrolledCount - roster.length;

  /// Số buổi sinh viên [uid] sẽ được ghi danh nếu thêm ngay.
  int eligibleCountFor(String uid) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return sessions
        .where(
          (s) =>
              !s.date.isBefore(today) &&
              !s.taken &&
              !s.studentIds.contains(uid),
        )
        .length;
  }

  Future<void> load() => run(() async {
    await _refresh();
  });

  Future<bool> enroll(String uid) => run(() async {
    lastAddedSessions = 0;
    lastAddedSessions = await _academic.enrollExistingStudent(
      classId: classId,
      studentUid: uid,
    );
    await _refresh();
  });

  Future<void> _refresh() async {
    course = await _academic.classById(classId);
    sessions = await _academic.sessionsOfClass(classId);
    roster = await _users.byIds(course!.studentIds);
    final joined = course!.studentIds.toSet();
    final all = await _users.students();
    candidates = [for (final u in all) if (!joined.contains(u.uid)) u];
  }
}
