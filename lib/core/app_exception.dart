/// Lỗi nghiệp vụ có thông báo tiếng Việt để hiển thị thẳng lên UI.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
