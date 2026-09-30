import '../data/models/app_user.dart';
import '../data/models/course_class.dart';
import '../data/repositories/academic_repository.dart';
import 'base_view_model.dart';

/// Danh sách lớp môn theo vai trò: giảng viên thấy lớp mình dạy, trưởng bộ
/// môn thấy lớp thuộc bộ môn, cán bộ đào tạo thấy mọi lớp.
class ClassListViewModel extends BaseViewModel {
  ClassListViewModel(this._repo, this.user);

  final AcademicRepository _repo;
  final AppUser user;

  List<CourseClass> classes = const [];

  Future<void> load() => run(() async {
    classes = switch (user.role) {
      UserRole.lecturer => await _repo.classesOfLecturer(user.uid),
      UserRole.head => await _repo.classesOfDepartment(user.department),
      UserRole.staff => await _repo.allClasses(),
      UserRole.student => await _repo.classesOfStudent(user.uid),
    };
  });
}
