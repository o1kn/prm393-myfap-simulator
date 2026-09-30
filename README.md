# myFAP Giả Lập (PRM393)

Ứng dụng Android viết bằng Flutter, quản lý đào tạo cho trường đại học với 4 vai trò: **cán bộ quản lý đào tạo**,
**trưởng bộ môn**, **giảng viên**, **sinh viên**.

## 1. Bài toán

Mỗi vai trò làm một phần việc, và kết quả của người này là dữ liệu người kia cần xem. Vì vậy cả 4 vai trò dùng **chung
một nguồn dữ liệu** (Cloud Firestore), để quy trình chạy trọn từ đầu đến cuối:

```
Cán bộ ĐT mở lớp + xếp lịch ─▶ Trưởng BM phân công GV ─▶ GV điểm danh ─▶ SV thấy có mặt / vắng, % vắng
                                                       └▶ GV nhập điểm, gửi duyệt ─▶ Trưởng BM công bố / trả lại ─▶ SV thấy điểm, Passed / Not passed
SV gửi đơn ─▶ Cán bộ ĐT chấp nhận / từ chối ─▶ SV thấy kết quả
Cán bộ ĐT đăng thông báo ─▶ SV / GV thấy theo đối tượng nhận
```

## 2. Kiến trúc

**Client – server.** Ứng dụng là client; máy chủ là **Firebase Auth + Cloud Firestore**, dùng chung cho 4 vai trò.
Luồng gọi: màn hình → ViewModel → Repository → Firebase.

**Trong app: MVVM với Provider.**

```
View (Widget)  ──gọi hàm──▶  ViewModel (ChangeNotifier)  ──▶  Repository  ──▶  Firebase Auth / Cloud Firestore
     ▲                              │                              │
     └──── notifyListeners ─────────┘                    domain/ (quy tắc nghiệp vụ, Dart thuần)
```

| Tầng | Thư mục | Phụ thuộc vào |
|---|---|---|
| View | `lib/views/` | ViewModel, model |
| ViewModel | `lib/viewmodels/` | Repository, domain, model (không import widget) |
| Repository | `lib/data/repositories/` | Firebase SDK, model, domain |
| Quy tắc nghiệp vụ | `lib/domain/` | chỉ model; Dart thuần, test không cần Firebase |
| Model | `lib/data/models/` | – |

```
lib/
├── main.dart                     khởi tạo Firebase rồi runApp
├── app/                          MaterialApp, route, theme
├── core/                         hằng số, AppException
├── data/
│   ├── models/                   AppUser, Subject, CourseClass, ClassSession, GradeRecord, ApplicationForm, AppNotification
│   └── repositories/             auth, user, academic (môn/lớp/lịch/điểm danh), grade, application, notification
├── domain/                       attendance_rules, grade_rules, schedule_rules
├── viewmodels/                   mỗi màn hình một ViewModel
└── views/                        splash, login, home (3 tab), các màn theo vai trò; widgets/ dùng chung
firebase/firestore.rules          phân quyền theo vai trò trên máy chủ
tool/seed.dart                    tạo tài khoản + dữ liệu mẫu
tool/probe_rules.dart             kiểm tra phân quyền trên Firebase thật
test/                             domain/, workflow/, widget/
```

Điều hướng: `Splash → Login → Home`. Home có 3 tab: Trang chủ (chức năng theo vai trò), Thông báo, Cá nhân.
Firebase Auth giữ phiên nên mở lại app vào thẳng Home.

## 3. Dữ liệu (Cloud Firestore)

| Collection | Khoá | Trường chính |
|---|---|---|
| `users` | uid | role (`staff`/`head`/`lecturer`/`student`), fullName, code, email, department |
| `subjects` | mã môn | name, credits, department, totalSessions, components[{name, weight, isFinal}] |
| `classes` | tự sinh | code, subjectCode, semester, department, studentIds[], lecturerId, gradeStatus (`draft`/`submitted`/`returned`/`published`), headNote |
| `sessions` | tự sinh | classId, sessionNo, date (`yyyy-MM-dd`), slot, room, studentIds[], lecturerId, attendance{uid: `present`/`absent`} |
| `grades` | `{classId}_{studentId}` | classId, studentId, subjectCode, semester, marks{đầu điểm: điểm}, published |
| `applications` | tự sinh | studentId, type, content, createdAt, status (`processing`/`approved`/`rejected`), staffNote, processedBy |
| `notifications` | tự sinh | title, content, audience (`all`/`students`/`lecturers`), createdAt, authorName |
| `userCodes` | mã người dùng | uid (chống trùng mã khi mở tài khoản) |

Quan hệ: `subjects` 1–n `classes`; `classes` 1–n `sessions`, 1–n `grades`; `users` n–n `classes` qua `studentIds`.
`studentIds` được chép sang `sessions` để sinh viên lấy lịch bằng một truy vấn `array-contains`.

## 4. Chức năng theo vai trò

| Vai trò | Chức năng |
|---|---|
| Cán bộ quản lý đào tạo | Mở lớp + xếp lịch cả kỳ (kiểm tra trùng phòng); xem chi tiết lớp; ghi danh muộn sinh viên vào các buổi chưa tới; xử lý đơn; đăng thông báo; mở tài khoản sinh viên / giảng viên |
| Trưởng bộ môn | Phân công giảng viên cho lớp thuộc bộ môn; duyệt bảng điểm: công bố hoặc trả lại kèm lý do |
| Giảng viên | Lịch dạy theo tuần; điểm danh từng buổi; nhập điểm, lưu nháp, gửi duyệt; cảnh báo khi rời màn hình còn thay đổi chưa lưu |
| Sinh viên | Lịch học tuần kèm trạng thái điểm danh; báo cáo điểm danh (% vắng, số buổi còn được vắng); điểm học kỳ; bảng điểm; gửi và theo dõi đơn |

## 5. Quy tắc nghiệp vụ

| Quy tắc | Nơi cài đặt |
|---|---|
| Không điểm danh buổi chưa tới ngày hoặc lớp đã công bố điểm | `domain/attendance_rules.dart` + rules |
| Vắng > 20% số buổi → không đủ điều kiện dự thi, môn Not passed | `domain/attendance_rules.dart`, `domain/grade_rules.dart` |
| Điểm 0–10; trung bình có trọng số, làm tròn 1 chữ số | `domain/grade_rules.dart` |
| Passed khi trung bình ≥ 5 và Final Exam ≥ 4 | `domain/grade_rules.dart` |
| Chỉ gửi duyệt khi mọi sinh viên đủ đầu điểm; đã gửi thì giảng viên không sửa | `grade_sheet_view_model.dart` + rules |
| Sinh viên chỉ thấy điểm đã công bố | `grade_repository.dart` + rules |
| Trưởng BM chỉ thao tác lớp và giảng viên cùng bộ môn | `academic_repository.dart` + rules |
| Mở lớp: mã dạng `SE1943`, không trùng mã trong kỳ, không trùng phòng + slot + ngày | `create_class_view_model.dart`, `domain/schedule_rules.dart` |
| Đơn: nội dung ≥ 10 ký tự; từ chối phải có lý do; đơn đã xử lý không xử lý lại | `application_repository.dart` + rules |
| Ghi danh muộn chỉ vào buổi chưa tới và chưa điểm danh | `academic_repository.dart::enrollExistingStudent` |
| Mã sinh viên / giảng viên không trùng | `user_repository.dart` (transaction với `userCodes`) |
| Thông báo chỉ hiện theo đối tượng nhận | `notification_repository.dart` + rules |

**Phân quyền trên máy chủ** (`firebase/firestore.rules`): mỗi quy tắc có chữ "rules" ở trên được kiểm tra cả ở Firestore,
nên sửa app hay gọi thẳng API cũng không vượt quyền được. Ví dụ: sinh viên không đọc được điểm của người khác, giảng viên
không sửa điểm lớp mình không dạy, trưởng bộ môn AI không duyệt lớp bộ môn SE.

## 6. Cài đặt và chạy

Firebase đã cấu hình sẵn: project `prm393-myfap-sim`, `android/app/google-services.json` có trong repo.

1. `flutter pub get`
2. `flutter run` trên thiết bị Android, hoặc cài bản release: `flutter build apk --release` →
   `build/app/outputs/flutter-apk/app-release.apk`
3. Làm mới dữ liệu demo (trước buổi demo): `firebase login` bằng tài khoản thành viên project → `dart run tool/seed.dart`
4. Sửa phân quyền: sửa `firebase/firestore.rules` → `firebase deploy --only firestore:rules`

Yêu cầu build: Flutter SDK, Android SDK kèm NDK 28.2.13676358.

### Tài khoản demo

Mật khẩu chung: `Myfap@2026`

| Vai trò | Email |
|---|---|
| Cán bộ quản lý đào tạo | daotao@myfap.vn |
| Trưởng bộ môn SE / AI | truongbm.se@myfap.vn / truongbm.ai@myfap.vn |
| Giảng viên | sonnt@myfap.vn (SE), hunglv@myfap.vn (AI) |
| Sinh viên | he170001@myfap.vn … he170005@myfap.vn |

## 7. Kiểm thử

### Test tự động

```bash
flutter analyze
flutter test                     # 41 test
dart run tool/probe_rules.dart   # 40 kiểm tra phân quyền trên Firebase thật
```

- `test/domain/` – quy tắc điểm, điểm danh, lịch.
- `test/workflow/` – quy trình 4 vai trò: mở lớp → phân công → điểm danh → nhập điểm → trả lại → công bố → sinh viên xem; đơn từ.
- `test/widget/` – các màn hình chính, cảnh báo chưa lưu, màn hình nhỏ 320dp với cỡ chữ 2x.
- `tool/probe_rules.dart` – đăng nhập từng vai trò rồi gọi thẳng Firestore REST (bỏ qua app), kiểm tra thao tác đúng quyền
  được cho phép và thao tác vượt quyền bị chặn; tự dọn dữ liệu thử.

### System test case

Chạy trên APK release với Firebase thật (30/09/2026). Ảnh chụp trong [`docs/demo/`](docs/demo).

| ID | Tài khoản | Các bước | Kết quả mong đợi | Ảnh |
|---|---|---|---|---|
| TC01 | daotao | Đăng nhập sai mật khẩu | "Sai email hoặc mật khẩu" | [ảnh](docs/demo/tc01_sai_mat_khau.png) |
| TC02 | daotao | Mở lớp SWD392 `SE1950`, phòng `BE-301`, slot 1, T4 | Báo trùng phòng với PRM393 - SE1943, không tạo lớp | [ảnh](docs/demo/tc02_trung_phong.png) |
| TC03 | daotao | Đổi phòng `BE-305`, slot 3, chọn HE170005 → Mở lớp | Lớp SE1950 được tạo, chưa có GV; HE170005 thấy lịch | [lớp](docs/demo/tc03_mo_lop.png), [SV](docs/demo/tc03_sv_thay_lich.png) |
| TC04 | truongbm.ai | Phân công giảng viên | Chỉ thấy lớp của bộ môn AI | [ảnh](docs/demo/tc04_tbm_ai_chi_thay_bo_mon_ai.png) |
| TC05 | truongbm.se | Phân công SWD392 - SE1944 cho Ngô Tùng Sơn | Lớp có GV sonnt5; lịch dạy của GV có SWD392 | [ảnh](docs/demo/tc05_phan_cong_gv.png) |
| TC06 | sonnt | Buổi PRM393 hôm nay → đánh vắng HE170002 → Lưu | "Đã lưu điểm danh" | [đánh vắng](docs/demo/tc06_danh_vang.png), [đã lưu](docs/demo/tc06_da_luu_diem_danh.png) |
| TC07 | he170002 | Lịch học tuần | Buổi PRM393 hôm nay hiện "Vắng" | [ảnh](docs/demo/tc07_sv_thay_vang.png) |
| TC08 | sonnt | Mở buổi PRM393 tuần sau | Chỉ xem, "Chưa diễn ra", không có nút lưu | [ảnh](docs/demo/tc08_buoi_chua_dien_ra.png) |
| TC09 | he170003 | Điểm danh → PRM393 | "Vắng 25% (5/20)" + cảnh báo không đủ điều kiện dự thi | [ảnh](docs/demo/tc09_vang_qua_20.png) |
| TC10 | sonnt | Nhập điểm 4 SV, bỏ trống HE170005 → Gửi duyệt | "Còn 1 sinh viên chưa đủ đầu điểm" | [ảnh](docs/demo/tc10_thieu_diem.png) |
| TC11 | sonnt | Nhập đủ → Gửi duyệt | "Chờ duyệt", ô điểm bị khoá | [ảnh](docs/demo/tc11_cho_duyet.png) |
| TC12 | he170001 | Điểm học kỳ → PRM393 | "Điểm chưa được công bố" | [ảnh](docs/demo/tc12_chua_cong_bo.png) |
| TC13 | truongbm.se | Trả lại bảng điểm PRM393 kèm lý do | "Bị trả lại" | [lý do](docs/demo/tc13_ly_do_tra_lai.png), [đã trả](docs/demo/tc13_da_tra_lai.png) |
| TC14 | sonnt → truongbm.se | GV thấy lý do, sửa Final Exam HE170004 3.5 → 4.5, gửi lại → Công bố | "Đã công bố" | [GV](docs/demo/tc14_gv_thay_ly_do.png), [công bố](docs/demo/tc14_da_cong_bo.png) |
| TC15 | he170001 / he170003 | Điểm học kỳ → PRM393 | HE170001 **Passed** (TB 7.9); HE170003 **Not passed** do vắng > 20% dù TB 8.5 | [Passed](docs/demo/tc15_passed.png), [Not passed](docs/demo/tc15_not_passed_vang.png) |
| TC16 | he170002 | Bảng điểm | AIL303m **Not passed** (Final Exam 3 < 4); tích luỹ 6 tín chỉ | [ảnh](docs/demo/tc16_bang_diem.png) |
| TC17 | he170001 | Gửi đơn nội dung "abc" | "Nội dung đơn cần ít nhất 10 ký tự" | [ảnh](docs/demo/tc17_noi_dung_ngan.png) |
| TC18 | he170001 | Gửi đơn nội dung đầy đủ | Đơn mới "Đang xử lý" | [ảnh](docs/demo/tc18_da_gui_don.png) |
| TC19 | daotao | Từ chối đơn, bỏ trống lý do | "Nhập lý do khi từ chối đơn" | [ảnh](docs/demo/tc19_tu_choi_thieu_ly_do.png) |
| TC20 | daotao → he170001 | Chấp nhận đơn kèm phản hồi | SV thấy "Đã được chấp nhận" + phản hồi | [cán bộ](docs/demo/tc20_cbdt_chap_nhan.png), [SV](docs/demo/tc20_sv_thay_ket_qua.png) |
| TC21 | daotao → he170001 / sonnt | Đăng thông báo cho "Sinh viên" | SV thấy, GV không thấy | [soạn](docs/demo/tc21_soan_thong_bao.png), [SV](docs/demo/tc21_sv_thay.png), [GV](docs/demo/tc21_gv_khong_thay.png) |
| TC22 | daotao | Chạm lớp PRM393 | Chi tiết lớp: GV, sĩ số, 20 buổi, danh sách SV | [ảnh](docs/demo/tc22_chi_tiet_lop.png) |
| TC23 | daotao | Mở lớp AIL303m (đã công bố) | Nút "Thêm sinh viên" bị khoá | [ảnh](docs/demo/tc23_lop_da_cong_bo.png) |
| TC24 | daotao → he170005 | SWD392 → Thêm sinh viên HE170005 | Chỉ ghi danh các buổi chưa tới; SV thấy lịch SWD392 | [chọn SV](docs/demo/tc24_chon_sinh_vien.png), [danh sách](docs/demo/tc22_roster_ghi_danh.png) |
| TC25 | daotao | Tạo tài khoản mã HE170001 (trùng) → đổi HE179999 | "Mã HE170001 đã tồn tại"; sau đó "Đã tạo tài khoản" | [form](docs/demo/tc25_form_tao_tai_khoan.png), [trùng mã](docs/demo/tc25_trung_ma.png), [đã tạo](docs/demo/tc25_da_tao.png) |
| TC26 | sonnt | Sửa điểm rồi bấm quay lại | Hỏi "Còn thay đổi chưa lưu" (Ở lại / Bỏ / Lưu) | [chưa lưu](docs/demo/tc26_chua_luu.png), [hộp thoại](docs/demo/tc26_hoi_bo_thay_doi.png) |
| TC27 | hunglv | Mở buổi AIL303m (lớp đã công bố) | Điểm danh chỉ xem, không sửa được | [ảnh](docs/demo/tc27_diem_danh_lop_cong_bo.png) |
| TC28 | he170002 | Bảng điểm → PRN212 → "Xem điểm danh môn này" | Mở điểm học kỳ rồi điểm danh đúng môn đó | [bảng điểm](docs/demo/tc28_bang_diem.png), [điểm danh môn](docs/demo/tc28_diem_danh_theo_mon.png) |
| TC29 | he170005 | Máy 320dp, cỡ chữ hệ thống 2.0 → Trang chủ | Chữ không bị cắt, ô số liệu tự xếp dọc | [ảnh](docs/demo/tc29_man_hinh_nho_sau.png) |

Điểm dùng ở TC10–TC15 (Assignment / Progress Test / Project / Final Exam):

| SV | Điểm | TB | Kết quả |
|---|---|---|---|
| HE170001 | 8 / 7.5 / 9 / 7 | 7.9 | Passed |
| HE170002 | 7 / 6 / 8 / 6.5 | 7.0 | Passed |
| HE170003 | 9 / 8 / 9 / 8 | 8.5 | Not passed – vắng 5/20 buổi |
| HE170004 | 6 / 5 / 7 / 4.5 | 5.7 | Passed |
| HE170005 | 5 / 4 / 5 / 5 | 4.8 | Not passed – TB dưới 5 |

## 8. Giới hạn

- Chỉ hỗ trợ Android.
- Rules không kiểm tra được "chỉ ghi danh vào buổi chưa tới" (ngày buổi học lưu dạng chuỗi); phần này do app kiểm tra.
