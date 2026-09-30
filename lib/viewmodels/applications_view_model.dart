import '../data/models/app_user.dart';
import '../data/models/application_form.dart';
import '../data/repositories/application_repository.dart';
import 'base_view_model.dart';

/// Đơn từ: sinh viên xem / gửi đơn của mình; cán bộ đào tạo xem và xử lý
/// mọi đơn.
class ApplicationsViewModel extends BaseViewModel {
  ApplicationsViewModel(this._repo, this.user);

  final ApplicationRepository _repo;
  final AppUser user;

  List<ApplicationForm> items = const [];

  bool get isStudent => user.role == UserRole.student;

  int get pendingCount =>
      items.where((a) => a.status == ApplicationStatus.processing).length;

  Future<void> load() => run(() async {
    items = isStudent ? await _repo.ofStudent(user.uid) : await _repo.all();
  });

  Future<bool> submit(String type, String content) => run(() async {
    await _repo.submit(user, type, content);
    items = await _repo.ofStudent(user.uid);
  });

  Future<bool> process(
    ApplicationForm form,
    ApplicationStatus decision,
    String note,
  ) => run(() async {
    await _repo.process(form, decision: decision, note: note, staff: user);
    items = await _repo.all();
  });
}
