import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/app_exception.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/user_repository.dart';
import '../base_view_model.dart';

/// Cán bộ đào tạo xem danh sách người dùng và mở tài khoản sinh viên /
/// giảng viên mới. Giữ nguyên phiên staff bằng FirebaseApp phụ có tên.
class StaffAccountsViewModel extends BaseViewModel {
  StaffAccountsViewModel(this._users);

  final UserRepository _users;

  /// Mật khẩu mặc định gán cho tài khoản mới. Chỉ hiện trên UI để staff
  /// báo cho người dùng đổi sau khi đăng nhập; không ghi log / lưu trữ.
  static const newAccountPassword = 'Myfap@2026';

  static const _secondaryName = 'staff-provisioning';

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _codePattern = RegExp(r'^[A-Za-z0-9]{3,20}$');

  List<AppUser> people = const [];
  String query = '';
  UserRole? roleFilter;

  /// Lọc theo vai trò + tìm theo tên / mã / email (không phân biệt hoa).
  List<AppUser> get filtered {
    final q = query.trim().toLowerCase();
    return [
      for (final p in people)
        if ((roleFilter == null || p.role == roleFilter) &&
            (q.isEmpty ||
                p.fullName.toLowerCase().contains(q) ||
                p.code.toLowerCase().contains(q) ||
                p.email.toLowerCase().contains(q)))
          p,
    ];
  }

  Future<void> load() => run(() async {
    people = await _users.all();
  });

  void setQuery(String value) {
    query = value;
    notify();
  }

  void setRoleFilter(UserRole? value) {
    roleFilter = value;
    notify();
  }

  /// Tạo tài khoản [role] mới với mật khẩu mặc định. Email trùng phải báo
  /// lỗi, không tái sử dụng tài khoản có sẵn. Ném [AppException] tiếng Việt.
  Future<bool> createAccount({
    required UserRole role,
    required String fullName,
    required String code,
    required String email,
    required String department,
  }) => run(() async {
    final name = fullName.trim();
    final codeTrimmed = code.trim();
    final emailNorm = email.trim().toLowerCase();
    final dept = department.trim().toUpperCase();

    if (role != UserRole.student && role != UserRole.lecturer) {
      throw const AppException('Chỉ được tạo sinh viên hoặc giảng viên');
    }
    if (name.length < 2) throw const AppException('Nhập họ tên (≥ 2 ký tự)');
    if (!_codePattern.hasMatch(codeTrimmed)) {
      throw const AppException('Mã từ 3 ký tự chữ/số (VD HE170001)');
    }
    if (!_emailPattern.hasMatch(emailNorm)) {
      throw const AppException('Email không hợp lệ');
    }
    if (role == UserRole.lecturer && dept != 'SE' && dept != 'AI') {
      throw const AppException('Giảng viên cần bộ môn SE hoặc AI');
    }
    if (role == UserRole.student && dept.isNotEmpty) {
      throw const AppException('Sinh viên không cần bộ môn');
    }
    if (await _users.isCodeReserved(codeTrimmed)) {
      throw AppException('Mã ${codeTrimmed.toUpperCase()} đã tồn tại');
    }

    FirebaseApp? secondary;
    try {
      try {
        secondary = Firebase.app(_secondaryName);
      } on FirebaseException {
        secondary = await Firebase.initializeApp(
          name: _secondaryName,
          options: Firebase.app().options,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);

      late final UserCredential cred;
      try {
        cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: emailNorm,
          password: newAccountPassword,
        );
      } on FirebaseAuthException catch (e) {
        throw AppException(switch (e.code) {
          'email-already-in-use' => 'Email đã được sử dụng',
          'invalid-email' => 'Email không hợp lệ',
          'network-request-failed' => 'Không có kết nối mạng',
          'too-many-requests' => 'Thử lại sau ít phút',
          _ => 'Không tạo được tài khoản: ${e.message ?? e.code}',
        });
      }

      final newUid = cred.user!.uid;
      final deptStored = role == UserRole.lecturer ? dept : '';
      try {
        await _users.createProfileWithCode(
          uid: newUid,
          role: role,
          fullName: name,
          code: codeTrimmed,
          email: emailNorm,
          department: deptStored,
        );
      } catch (original) {
        // Commit có thể đã thành công mà lỗi trả về mơ hồ (mất mạng sau
        // khi server đã ghi). Đọc lại trước khi thu hồi Auth.
        bool committed;
        try {
          committed = await _users.isCommitted(
            uid: newUid,
            code: codeTrimmed,
          );
        } catch (_) {
          committed = false;
          try {
            await cred.user!.delete();
          } catch (_) {
            throw AppException(
              '${_messageOf(original)}. Không xác định được hồ sơ đã ghi '
              'hay chưa và không xoá được tài khoản Auth mới (uid $newUid) '
              '— kiểm tra thủ công, tài khoản chưa hoàn chỉnh.',
            );
          }
          throw AppException(
            '${_messageOf(original)}. Hồ sơ có thể chưa được ghi; tài khoản '
            'Auth mới đã được thu hồi.',
          );
        }
        if (!committed) {
          try {
            await cred.user!.delete();
          } catch (_) {
            throw AppException(
              '${_messageOf(original)}. Không xoá được tài khoản Auth mới '
              '(uid $newUid) — kiểm tra thủ công, tài khoản chưa hoàn chỉnh.',
            );
          }
          rethrow;
        }
        // Đã ghi xong: giữ tài khoản để người dùng mới đăng nhập được.
      }
      people = await _users.all();
    } finally {
      // Luôn đăng xuất app phụ và huỷ để không rò rỉ phiên; phiên staff
      // trên FirebaseAuth.instance mặc định không bị đụng tới.
      if (secondary != null) {
        try {
          await FirebaseAuth.instanceFor(app: secondary).signOut();
        } catch (_) {
          // Bỏ qua: dọn dẹp best-effort, không che lỗi gốc.
        }
        try {
          await secondary.delete();
        } catch (_) {
          // Bỏ qua tương tự.
        }
      }
    }
  });

  static String _messageOf(Object e) =>
      e is AppException ? e.message : e.toString();
}
