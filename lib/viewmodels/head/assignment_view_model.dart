import '../../data/models/app_user.dart';
import '../../data/models/course_class.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../base_view_model.dart';

/// Trưởng bộ môn phân công giảng viên cho các lớp thuộc bộ môn.
class AssignmentViewModel extends BaseViewModel {
  AssignmentViewModel(this._academic, this._users, this.head);

  final AcademicRepository _academic;
  final UserRepository _users;
  final AppUser head;

  List<CourseClass> classes = const [];
  List<AppUser> lecturers = const [];

  int get unassignedCount => classes.where((c) => c.lecturerId == null).length;

  Future<void> load() => run(() async {
    classes = await _academic.classesOfDepartment(head.department);
    lecturers = await _users.lecturersOf(head.department);
  });

  Future<bool> assign(CourseClass course, AppUser lecturer) => run(() async {
    await _academic.assignLecturer(course, lecturer);
    classes = await _academic.classesOfDepartment(head.department);
  });
}
