import '../data/models/app_user.dart';
import '../data/repositories/auth_repository.dart';
import 'base_view_model.dart';

/// Phiên đăng nhập toàn app. Splash gọi [restore]; Login gọi [signIn].
class AuthViewModel extends BaseViewModel {
  AuthViewModel(this._repo);

  final AuthRepository _repo;

  AppUser? _user;

  AppUser? get user => _user;

  Future<void> restore() =>
      run(() async => _user = await _repo.restoreSession());

  Future<bool> signIn(String email, String password) =>
      run(() async => _user = await _repo.signIn(email, password));

  Future<void> signOut() async {
    await _repo.signOut();
    _user = null;
    notify();
  }
}
