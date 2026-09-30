# myFAP – Ứng dụng giả lập (PRM393)

App Android viết bằng Flutter, giả lập hệ thống FAP / myFAP của Đại học FPT với 4 vai trò: **cán bộ quản lý đào tạo**,
**trưởng bộ môn**, **giảng viên**, **sinh viên**.

Phân tích ứng dụng gốc (myFAP 2.0.5 dịch ngược + web FAP): [`docs/phan_tich_myfap_goc.md`](docs/phan_tich_myfap_goc.md).

## 1. Bài toán

myFAP gốc là app **chỉ để xem** của sinh viên: lịch học, điểm danh, điểm, bảng điểm, đơn từ, thông báo. Dữ liệu do cán bộ
đào tạo, trưởng bộ môn và giảng viên tạo trên web FAP. Bản giả lập đưa cả 4 vai trò vào cùng một app, chạy trên **một nguồn
dữ liệu chung** (Cloud Firestore), để một quy trình đi trọn từ đầu đến cuối:

```
Cán bộ ĐT mở lớp + xếp lịch ─▶ Trưởng BM phân công GV ─▶ GV điểm danh ─▶ SV thấy có mặt / vắng, % vắng
                                                       └▶ GV nhập điểm, gửi duyệt ─▶ Trưởng BM công bố / trả lại ─▶ SV thấy điểm, Passed / Not passed
SV gửi đơn ─▶ Cán bộ ĐT chấp nhận / từ chối ─▶ SV thấy trạng thái đơn
Cán bộ ĐT đăng thông báo ─▶ SV / GV thấy theo đối tượng nhận
```

## 2. Kiến trúc

**Client – server, giống myFAP gốc.** App gốc: màn hình → tầng service → REST API `/api/MyFAP/*` trên máy chủ FAP.
Bản giả lập: màn hình → ViewModel → Repository → **Firebase Auth + Cloud Firestore** (máy chủ dùng chung cho 4 vai trò).

**Trong app: MVVM với Provider** (Module 5, 8, 10, 11 của môn học).

```
View (Widget)  ──gọi hàm──▶  ViewModel (ChangeNotifier)  ──▶  Repository  ──▶  Firebase Auth / Cloud Firestore
     ▲                              │                              │
     └──── notifyListeners ─────────┘                    domain/ (quy tắc nghiệp vụ, Dart thuần)
```

| Tầng | Thư mục | Được phụ thuộc vào |
|---|---|---|
| View | `lib/views/` | ViewModel, model |
| ViewModel | `lib/viewmodels/` | Repository, domain, model — không import widget |
| Repository | `lib/data/repositories/` | Firebase SDK, model, domain |
| Quy tắc nghiệp vụ | `lib/domain/` | chỉ model; Dart thuần, test không cần Firebase |
| Model | `lib/data/models/` | – |

```
lib/
├── main.dart                     Firebase.initializeApp() rồi runApp
├── app/                          MaterialApp, route, theme (màu navy #1a2e4a của myFAP)
├── core/                         hằng số, AppException, tài khoản demo
├── data/
│   ├── models/                   AppUser, Subject, CourseClass, ClassSession, GradeRecord, ApplicationForm, AppNotification
│   └── repositories/             auth, user, academic (môn/lớp/lịch/điểm danh), grade, application, notification
├── domain/                       attendance_rules, grade_rules, schedule_rules
├── viewmodels/                   mỗi màn hình một ViewModel; student/, lecturer/, head/, staff/
└── views/                        splash, login, home (3 tab), notifications, timetable, applications, class list,
                                  grade sheet; student/, lecturer/, head/, staff/
firebase/firestore.rules          Phân quyền theo vai trò trên máy chủ
tool/seed.dart                    Tạo tài khoản + dữ liệu mẫu trên Firebase
test/                             domain/ (quy tắc), workflow/ (quy trình 4 vai trò), widget/
```

Điều hướng: `Splash → Login → Home` bằng `pushReplacementNamed` (Module 10). Home có 3 tab như myFAP gốc: Trang chủ (lưới
chức năng theo vai trò), Thông báo, Cá nhân. Firebase Auth tự lưu phiên nên mở lại app vào thẳng Home.

## 3. Thiết kế dữ liệu (Cloud Firestore)

| Collection | Khoá | Trường chính |
|---|---|---|
| `users` | uid Firebase Auth | role (`staff`/`head`/`lecturer`/`student`), fullName, code, email, department |
| `subjects` | mã môn | name, credits, department, totalSessions, components[{name, weight, isFinal}] |
| `classes` | tự sinh | code, subjectCode, subjectName, semester, department, studentIds[], lecturerId, lecturerName, gradeStatus (`draft`/`submitted`/`returned`/`published`), headNote |
| `sessions` | tự sinh | classId, classCode, subjectCode, sessionNo, date (`yyyy-MM-dd`), slot, room, studentIds[], lecturerId, lecturerName, attendance{uid: `present`/`absent`} |
| `grades` | `{classId}_{studentId}` | classId, studentId, studentName, studentCode, subjectCode, semester, marks{đầu điểm: điểm}, published |
| `applications` | tự sinh | studentId, studentName, studentCode, type, content, createdAt, status (`processing`/`approved`/`rejected`), staffNote, processedBy, processedAt |
| `notifications` | tự sinh | title, content, audience (`all`/`students`/`lecturers`), createdAt, authorName |

Quan hệ: `classes` 1–n `sessions`; `classes` 1–n `grades`; `subjects` 1–n `classes`; `users` n–n `classes` qua `studentIds`.
`studentIds` được chép sang `sessions` để sinh viên lấy lịch bằng một truy vấn `array-contains`.

Phân quyền (`firebase/firestore.rules`): sinh viên chỉ đọc điểm của mình khi `published == true` và chỉ đọc đơn của mình;
giảng viên chỉ sửa điểm danh buổi mình dạy và chỉ ghi điểm lớp mình khi bảng điểm ở `draft`/`returned`; trưởng bộ môn chỉ
thao tác lớp thuộc bộ môn; cán bộ đào tạo mở lớp, xử lý đơn, đăng thông báo.

## 4. Chức năng theo vai trò

| Vai trò | Chức năng |
|---|---|
| Cán bộ quản lý đào tạo | Mở lớp môn + xếp lịch cả kỳ (ngày bắt đầu, thứ, slot, phòng, sinh viên); xử lý đơn từ; đăng thông báo |
| Trưởng bộ môn | Phân công giảng viên cho lớp thuộc bộ môn; duyệt bảng điểm: công bố hoặc trả lại kèm lý do |
| Giảng viên | Lịch dạy theo tuần; điểm danh từng buổi; nhập điểm thành phần, lưu nháp, gửi duyệt |
| Sinh viên | Lịch học tuần kèm trạng thái điểm danh; báo cáo điểm danh (% vắng); điểm học kỳ; bảng điểm; gửi và theo dõi đơn |

## 5. Quy tắc nghiệp vụ

| Quy tắc | Nơi cài đặt |
|---|---|
| Không điểm danh buổi chưa tới ngày | `domain/attendance_rules.dart` |
| Vắng > 20% tổng số buổi → không đủ điều kiện dự thi, môn Not passed | `domain/attendance_rules.dart`, `domain/grade_rules.dart` |
| Điểm 0–10; trung bình có trọng số, làm tròn 1 chữ số | `domain/grade_rules.dart` |
| Passed khi trung bình ≥ 5 và Final Exam ≥ 4 | `domain/grade_rules.dart` |
| Chỉ gửi duyệt khi mọi sinh viên đủ đầu điểm; đã gửi thì giảng viên không sửa | `viewmodels/grade_sheet_view_model.dart` |
| Sinh viên chỉ thấy điểm đã công bố | `grade_repository.dart` + Firestore rules |
| Trưởng BM chỉ phân công GV cùng bộ môn | `academic_repository.dart` |
| Mở lớp: mã lớp dạng `SE1943`, không trùng mã trong kỳ, không trùng phòng + slot + ngày | `staff/create_class_view_model.dart`, `domain/schedule_rules.dart` |
| Đơn: nội dung ≥ 10 ký tự; từ chối phải có lý do; đơn đã xử lý không xử lý lại (transaction) | `application_repository.dart` |

## 6. System test case (kịch bản demo)

Đã chạy đủ 21 case ngày 30/09/2026 trên **APK release** (emulator Android 16, API 36) với **Firebase thật**
(`prm393-myfap-sim`, rules thật). Ảnh chụp trong [`docs/demo/`](docs/demo). Mật khẩu mọi tài khoản: `Myfap@2026`.

Chạy `dart run tool/seed.dart` ngay trước khi demo: lịch PRM393 có một buổi rơi đúng ngày seed.

| ID | Tài khoản | Các bước | Kết quả mong đợi | Ảnh |
|---|---|---|---|---|
| TC01 | daotao@myfap.vn | Đăng nhập với mật khẩu sai | Báo "Sai email hoặc mật khẩu", ở lại màn Login | [tc01](docs/demo/tc01_sai_mat_khau.png) |
| TC02 | daotao@myfap.vn | Lớp môn & lịch học → Mở lớp: SWD392, mã `SE1950`, phòng `BE-301`, slot 1, T4 | Báo "Phòng BE-301 slot 1 ngày … đã có lớp PRM393 - SE1943", không tạo lớp | [tc02](docs/demo/tc02_trung_phong.png) |
| TC03 | daotao@myfap.vn | Đổi phòng `BE-305`, slot 3, T2 + T4, chọn HE170005 → Mở lớp | Lớp SE1950 xuất hiện, "Đang nhập điểm", GV "chưa phân công"; HE170005 thấy lịch SWD392 | [lớp](docs/demo/tc03_mo_lop.png), [SV](docs/demo/tc03_sv_thay_lich.png) |
| TC04 | truongbm.ai@myfap.vn | Phân công giảng viên | Chỉ thấy lớp AIL303m của bộ môn AI | [tc04](docs/demo/tc04_tbm_ai_chi_thay_bo_mon_ai.png) |
| TC05 | truongbm.se@myfap.vn | Phân công → SWD392 - SE1944 → Ngô Tùng Sơn | "Giảng viên: sonnt5"; lịch dạy của sonnt có SWD392 | [tc05](docs/demo/tc05_phan_cong_gv.png) |
| TC06 | sonnt@myfap.vn | Lịch dạy & điểm danh → buổi PRM393 hôm nay → tắt HE170002 → Lưu điểm danh | "Đã lưu điểm danh"; buổi có dấu tích | [đánh vắng](docs/demo/tc06_danh_vang.png), [đã lưu](docs/demo/tc06_da_luu_diem_danh.png) |
| TC07 | he170002@myfap.vn | Lịch học tuần | Buổi PRM393 hôm nay hiện "Vắng" | [tc07](docs/demo/tc07_sv_thay_vang.png) |
| TC08 | sonnt@myfap.vn | Tuần sau → buổi PRM393 | "Buổi học chưa diễn ra: chỉ xem", mọi SV "Chưa diễn ra", không có nút lưu | [tc08](docs/demo/tc08_buoi_chua_dien_ra.png) |
| TC09 | he170003@myfap.vn | Điểm danh → PRM393 | "Vắng 25% (5/20 buổi)" + cảnh báo không đủ điều kiện dự thi | [tc09](docs/demo/tc09_vang_qua_20.png) |
| TC10 | sonnt@myfap.vn | Nhập điểm → PRM393 → nhập điểm 4 SV đầu (bảng dưới), để trống HE170005 → Gửi duyệt | "Còn 1 sinh viên chưa đủ đầu điểm"; vẫn "Đang nhập điểm" | [tc10](docs/demo/tc10_thieu_diem.png) |
| TC11 | sonnt@myfap.vn | Nhập điểm HE170005 → Gửi duyệt | "Chờ duyệt"; ô điểm bị khoá | [tc11](docs/demo/tc11_cho_duyet.png) |
| TC12 | he170001@myfap.vn | Điểm học kỳ → PRM393 | "Điểm chưa được công bố", "Đang học" | [tc12](docs/demo/tc12_chua_cong_bo.png) |
| TC13 | truongbm.se@myfap.vn | Duyệt bảng điểm → PRM393 → Trả lại, lý do "Kiểm tra lại Final Exam của Đỗ Khánh Linh" | "Bị trả lại" | [lý do](docs/demo/tc13_ly_do_tra_lai.png), [đã trả](docs/demo/tc13_da_tra_lai.png) |
| TC14 | sonnt → truongbm.se | GV thấy lý do, sửa Final Exam HE170004 3.5 → 4.5, gửi lại → Trưởng BM Công bố | "Đã công bố" | [GV](docs/demo/tc14_gv_thay_ly_do.png), [công bố](docs/demo/tc14_da_cong_bo.png) |
| TC15 | he170001 / he170003 | Điểm học kỳ → PRM393 | HE170001: **Passed**, TB 7.9. HE170003: **Not passed** – "Vắng quá 20% số buổi" dù TB 8.5 | [Passed](docs/demo/tc15_passed.png), [Not passed](docs/demo/tc15_not_passed_vang.png) |
| TC16 | he170002@myfap.vn | Bảng điểm | AIL303m **Not passed** (TB 5.6 nhưng Final Exam 3); PRM393, PRN212 **Passed**; tích luỹ 6 tín chỉ | [tc16](docs/demo/tc16_bang_diem.png) |
| TC17 | he170001@myfap.vn | Đơn từ → Gửi đơn "Xin tạm nghỉ một học kỳ", nội dung "abc" | "Nội dung đơn cần ít nhất 10 ký tự" ngay trong form | [tc17](docs/demo/tc17_noi_dung_ngan.png) |
| TC18 | he170001@myfap.vn | Nhập nội dung đầy đủ → Gửi | Đơn mới "Đang xử lý" | [tc18](docs/demo/tc18_da_gui_don.png) |
| TC19 | daotao@myfap.vn | Xử lý đơn từ → Từ chối đơn của HE170001, để trống lý do | "Nhập lý do khi từ chối đơn" | [tc19](docs/demo/tc19_tu_choi_thieu_ly_do.png) |
| TC20 | daotao → he170001 | Chấp nhận kèm phản hồi → SV mở Đơn từ | "Đã được chấp nhận", người xử lý, phản hồi | [cán bộ](docs/demo/tc20_cbdt_chap_nhan.png), [SV](docs/demo/tc20_sv_thay_ket_qua.png) |
| TC21 | daotao → he170001 / sonnt | Thông báo → Đăng thông báo, đối tượng "Sinh viên" | SV thấy thông báo; GV không thấy | [soạn](docs/demo/tc21_soan_thong_bao.png), [SV](docs/demo/tc21_sv_thay.png), [GV](docs/demo/tc21_gv_khong_thay.png) |

Điểm dùng ở TC10–TC11 (Assignment / Progress Test / Project / Final Exam):

| SV | Điểm | TB | Kết quả sau công bố |
|---|---|---|---|
| HE170001 | 8 / 7.5 / 9 / 7 | 7.9 | Passed |
| HE170002 | 7 / 6 / 8 / 6.5 | 7.0 | Passed (vắng 1/20 buổi) |
| HE170003 | 9 / 8 / 9 / 8 | 8.5 | Not passed – vắng 5/20 buổi |
| HE170004 | 6 / 5 / 7 / 3.5 → 4.5 (TC14) | 5.7 | Passed |
| HE170005 | 5 / 4 / 5 / 5 | 4.8 | Not passed – TB dưới 5 |

Mở lại app sau khi đã đăng nhập thì vào thẳng Trang chủ (Firebase Auth giữ phiên): [ảnh](docs/demo/gv_trang_chu_tu_dang_nhap.png).

Test tự động: `test/workflow/business_process_test.dart` (mở lớp → phân công → điểm danh → nhập điểm → trả lại → công bố
→ SV xem; đơn từ), `test/domain/rules_test.dart`, `test/widget/` (điểm danh, form gửi đơn).

### Kiểm tra phân quyền trên Firebase thật

Gọi thẳng Firestore REST bằng ID token của từng tài khoản (bỏ qua app), 30/09/2026:

| Thao tác | Kết quả |
|---|---|
| SV đọc điểm đã công bố của mình | Cho phép (200) |
| SV đọc điểm của SV khác / truy vấn toàn bộ điểm của lớp | Chặn (403) |
| SV tự đổi `role` thành `staff` | Chặn (403) |
| SV gửi đơn đứng tên SV khác / đọc đơn của SV khác / đăng thông báo | Chặn (403) |
| GV điểm danh lớp mình không dạy / sửa điểm lớp đã công bố | Chặn (403) |
| Trưởng BM AI trả lại bảng điểm lớp bộ môn SE | Chặn (403) |
| Cán bộ ĐT xử lý lại đơn đã duyệt | Chặn (403) |

## 7. Cài đặt và chạy

Firebase đã dựng sẵn: project **`prm393-myfap-sim`** (Firestore `asia-southeast1`, Auth Email/Password, rules đã
triển khai). `android/app/google-services.json` đã có trong repo.

1. `flutter pub get`
2. Chạy: `flutter run` trên thiết bị Android. Bản release: `flutter build apk --release` →
   `build/app/outputs/flutter-apk/app-release.apk`.
3. Reset dữ liệu demo (ngay trước buổi demo, khoảng 2 phút): `firebase login` bằng tài khoản thành viên project, rồi
   `dart run tool/seed.dart`. Seed ghi bằng quyền quản trị project nên không cần mở rules.
4. Sửa phân quyền: sửa `firebase/firestore.rules` rồi `firebase deploy --only firestore:rules`.
5. Cho thành viên nhóm chạy bước 3–4: Firebase console → Project settings → Users and permissions → Add member.

Build Android cần **NDK 28.2.13676358**. Nếu Gradle báo không cài được NDK, mở Android Studio → SDK Manager → SDK Tools →
NDK (Side by side) để cài; thư mục SDK `C:\Android\Sdk` cần quyền ghi (chạy Android Studio bằng quyền admin).

```bash
flutter pub get
flutter analyze
flutter test
```
