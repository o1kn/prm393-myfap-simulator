/// Tài khoản mẫu do `tool/seed.dart` tạo trên Firebase. Màn đăng nhập hiện
/// danh sách này để demo nhanh theo từng vai trò.
library;

const demoPassword = 'Myfap@2026';

typedef DemoAccount = ({String email, String label});

const demoAccounts = <DemoAccount>[
  (email: 'daotao@myfap.vn', label: 'Cán bộ đào tạo'),
  (email: 'truongbm.se@myfap.vn', label: 'Trưởng BM SE'),
  (email: 'sonnt@myfap.vn', label: 'Giảng viên SE'),
  (email: 'he170001@myfap.vn', label: 'Sinh viên HE170001'),
  (email: 'he170002@myfap.vn', label: 'Sinh viên HE170002'),
];
