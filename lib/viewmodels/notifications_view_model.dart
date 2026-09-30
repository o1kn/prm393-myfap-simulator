import '../data/models/app_notification.dart';
import '../data/models/app_user.dart';
import '../data/repositories/notification_repository.dart';
import 'base_view_model.dart';

class NotificationsViewModel extends BaseViewModel {
  NotificationsViewModel(this._repo, this.user);

  final NotificationRepository _repo;
  final AppUser user;

  List<AppNotification> items = const [];

  bool get canPublish => user.role == UserRole.staff;

  Future<void> load() =>
      run(() async => items = await _repo.forRole(user.role));

  Future<bool> publish(String title, String content, Audience audience) =>
      run(() async {
        await _repo.publish(
          author: user,
          title: title,
          content: content,
          audience: audience,
        );
        items = await _repo.forRole(user.role);
      });
}
