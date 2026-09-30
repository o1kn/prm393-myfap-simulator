import '../../core/app_exception.dart';
import '../../data/models/app_user.dart';
import '../../data/models/subject.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../base_view_model.dart';

/// Cán bộ đào tạo mở lớp môn: chọn môn, mã lớp, sinh viên và lịch học.
class CreateClassViewModel extends BaseViewModel {
  CreateClassViewModel(this._academic, this._users);

  final AcademicRepository _academic;
  final UserRepository _users;

  List<Subject> subjects = const [];
  List<AppUser> students = const [];

  Subject? subject;
  final Set<String> selectedStudents = {};
  final Set<int> weekdays = {};
  String? createdClassId;
  int slot = 1;
  DateTime startDate = DateTime.now();
  Future<void> load() => run(() async {
    subjects = await _academic.subjects();
    students = await _users.students();
  });

  void setSubject(Subject? value) {
    subject = value;
    notify();
  }

  void toggleStudent(String uid) {
    selectedStudents.contains(uid)
        ? selectedStudents.remove(uid)
        : selectedStudents.add(uid);
    notify();
  }

  void toggleWeekday(int weekday) {
    weekdays.contains(weekday)
        ? weekdays.remove(weekday)
        : weekdays.add(weekday);
    notify();
  }

  void setSlot(int value) {
    slot = value;
    notify();
  }

  void setStartDate(DateTime value) {
    startDate = value;
    notify();
  }

  Future<bool> create({required String classCode, required String room}) =>
      run(() async {
        if (subject == null) throw const AppException('Chọn môn học');
        if (!RegExp(r'^[A-Za-z]{2}\d{4}$').hasMatch(classCode.trim())) {
          throw const AppException('Mã lớp dạng SE1943');
        }
        if (room.trim().isEmpty) throw const AppException('Nhập phòng học');
        if (weekdays.isEmpty) throw const AppException('Chọn thứ học');
        if (selectedStudents.isEmpty) {
          throw const AppException('Chọn ít nhất một sinh viên');
        }
        createdClassId = await _academic.createClassWithSchedule(
          subject: subject!,
          classCode: classCode,
          studentIds: selectedStudents.toList(),
          startDate: startDate,
          weekdays: weekdays,
          slot: slot,
          room: room,
        );
      });
}
