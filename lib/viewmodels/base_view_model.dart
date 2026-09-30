import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/app_exception.dart';

/// ViewModel cơ sở: gói trạng thái tải / lỗi dùng chung cho mọi màn hình.
abstract class BaseViewModel extends ChangeNotifier {
  bool _busy = false;
  String? _error;
  bool _disposed = false;

  bool get busy => _busy;

  /// Lỗi của thao tác gần nhất (null = thành công).
  String? get error => _error;

  /// Chạy [task], bật cờ [busy] và chuyển lỗi thành thông báo tiếng Việt.
  /// Trả về true nếu thành công.
  @protected
  Future<bool> run(Future<void> Function() task) async {
    _busy = true;
    _error = null;
    notify();
    try {
      await task();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } on FirebaseException catch (e) {
      _error = e.code == 'permission-denied'
          ? 'Bạn không có quyền thực hiện thao tác này'
          : 'Lỗi máy chủ: ${e.message ?? e.code}';
      return false;
    } finally {
      _busy = false;
      notify();
    }
  }

  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
