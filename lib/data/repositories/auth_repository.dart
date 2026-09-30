import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_exception.dart';
import '../../core/constants.dart';
import '../models/app_user.dart';

/// Đăng nhập bằng Firebase Auth rồi đọc hồ sơ + vai trò ở `users/{uid}`.
/// Firebase Auth tự lưu phiên, nên mở lại app không phải đăng nhập lại.
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Future<AppUser> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return await _loadProfile(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      throw AppException(switch (e.code) {
        'invalid-email' => 'Email không hợp lệ',
        'user-disabled' => 'Tài khoản đã bị khoá',
        'network-request-failed' => 'Không có kết nối mạng',
        'too-many-requests' => 'Thử lại sau ít phút',
        _ => 'Sai email hoặc mật khẩu',
      });
    }
  }

  /// Phiên đăng nhập còn hiệu lực từ lần mở app trước (null = chưa đăng nhập).
  Future<AppUser?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _loadProfile(user.uid);
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppUser> _loadProfile(String uid) async {
    final doc = await _db.collection(Collections.users).doc(uid).get();
    if (!doc.exists) {
      await _auth.signOut();
      throw const AppException('Tài khoản chưa được cấp quyền trên hệ thống');
    }
    return AppUser.fromMap(uid, doc.data()!);
  }
}
