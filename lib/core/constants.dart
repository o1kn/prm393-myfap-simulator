/// Hằng số dùng chung toàn app.
library;

/// Học kỳ đang vận hành trong bản giả lập.
const currentSemester = 'Fall2026';

/// Tên collection trên Cloud Firestore.
abstract final class Collections {
  static const users = 'users';
  static const subjects = 'subjects';
  static const classes = 'classes';
  static const sessions = 'sessions';
  static const grades = 'grades';
  static const applications = 'applications';
  static const notifications = 'notifications';
}

/// Khung giờ các slot trong ngày.
const slotTimes = <int, String>{
  1: '07:30 - 09:50',
  2: '10:00 - 12:20',
  3: '12:50 - 15:10',
  4: '15:20 - 17:40',
};

/// Danh mục loại đơn sinh viên được gửi.
const applicationTypes = <String>[
  'Xin chuyển lớp học',
  'Xin tạm nghỉ một học kỳ',
  'Xác nhận sinh viên',
  'Xác nhận sinh viên để hoãn nghĩa vụ quân sự',
  'Xác nhận vay vốn ngân hàng',
  'Hủy đăng ký học lại',
  'Các loại đơn khác',
];

/// Tỉ lệ vắng tối đa; vượt ngưỡng thì không đủ điều kiện dự thi.
const maxAbsentRate = 0.2;
