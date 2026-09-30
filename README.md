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

Chạy `dart run tool/seed.dart` ngay trước khi demo: lịch PRM393 có một buổi rơi đúng ngày seed. Mật khẩu mọi tài khoản:
`Myfap@2026`.

| ID | Tài khoản | Các bước | Kết quả mong đợi |
|---|---|---|---|
| TC01 | bất kỳ | Đăng nhập với mật khẩu sai | Báo "Sai email hoặc mật khẩu", ở lại màn Login |
| TC02 | daotao@myfap.vn | Lớp môn & lịch học → Mở lớp: SWD392, mã `SE1950`, phòng `BE-301`, slot 1, chọn thứ trùng lịch PRM393 | Báo "Phòng BE-301 slot 1 ngày … đã có lớp PRM393 - SE1943", không tạo lớp |
| TC03 | daotao@myfap.vn | Mở lớp SWD392 `SE1950`, phòng `BE-305`, slot 3, T2 + T4, chọn HE170005 | Lớp xuất hiện, trạng thái "Đang nhập điểm", GV "chưa phân công"; HE170005 thấy lịch SWD392 |
| TC04 | truongbm.ai@myfap.vn | Phân công giảng viên | Không thấy lớp nào của bộ môn SE |
| TC05 | truongbm.se@myfap.vn | Phân công giảng viên → SWD392 - SE1944 → chọn Ngô Tùng Sơn | Lớp hiện "Giảng viên: sonnt5"; lịch dạy của sonnt có SWD392; lịch học của HE170001 hiện GV sonnt5 |
| TC06 | sonnt@myfap.vn | Lịch dạy & điểm danh → buổi PRM393 hôm nay → tắt HE170002 → Lưu điểm danh | Báo "Đã lưu điểm danh"; buổi có dấu đã điểm danh |
| TC07 | he170002@myfap.vn | Lịch học tuần | Buổi PRM393 hôm nay hiện "Vắng" |
| TC08 | sonnt@myfap.vn | Mở một buổi PRM393 của tuần sau | "Buổi học chưa diễn ra: chỉ xem", không có nút lưu |
| TC09 | he170003@myfap.vn | Điểm danh → PRM393 | "Vắng 25% (5/20 buổi)" và cảnh báo không đủ điều kiện dự thi |
| TC10 | sonnt@myfap.vn | Nhập điểm → PRM393 → nhập đủ 4 đầu điểm cho 4/5 sinh viên → Gửi duyệt | Báo "Còn 1 sinh viên chưa đủ đầu điểm"; trạng thái vẫn "Đang nhập điểm" |
| TC11 | sonnt@myfap.vn | Nhập nốt sinh viên còn lại → Gửi duyệt | Trạng thái "Chờ duyệt"; ô điểm bị khoá |
| TC12 | he170001@myfap.vn | Điểm học kỳ → PRM393 | "Điểm chưa được công bố", trạng thái "Đang học" |
| TC13 | truongbm.se@myfap.vn | Duyệt bảng điểm → PRM393 → Trả lại, lý do "Kiểm tra lại Final Exam" | Trạng thái "Bị trả lại"; GV thấy lý do và sửa được điểm |
| TC14 | sonnt → truongbm.se | GV gửi lại → Trưởng BM bấm Công bố | Trạng thái "Đã công bố" |
| TC15 | he170001 / he170003 | Điểm học kỳ → PRM393 | HE170001: điểm từng đầu, trung bình, **Passed**. HE170003: **Not passed** – "Vắng quá 20% số buổi" |
| TC16 | he170002@myfap.vn | Bảng điểm | AIL303m **Not passed** (Final Exam dưới 4) không cộng tín chỉ; PRN212 **Passed** cộng 3 tín chỉ |
| TC17 | he170001@myfap.vn | Đơn từ → Gửi đơn "Xin tạm nghỉ một học kỳ", nội dung "abc" | Báo "Nội dung đơn cần ít nhất 10 ký tự" |
| TC18 | he170001@myfap.vn | Gửi lại với nội dung đầy đủ | Đơn mới trạng thái "Đang xử lý" |
| TC19 | daotao@myfap.vn | Xử lý đơn từ → Từ chối đơn của HE170001, để trống lý do | Báo "Nhập lý do khi từ chối đơn" |
| TC20 | daotao → he170001 | Chấp nhận đơn, phản hồi "Đã duyệt" → SV mở Đơn từ | "Đã được chấp nhận", người xử lý, phản hồi |
| TC21 | daotao → he170001 / sonnt | Thông báo → Đăng thông báo, đối tượng "Sinh viên" | Sinh viên thấy thông báo; giảng viên không thấy |

Test tự động phủ các quy trình trên: `test/workflow/business_process_test.dart` (mở lớp → phân công → điểm danh → nhập
điểm → trả lại → công bố → sinh viên xem; đơn từ), `test/domain/rules_test.dart`, `test/widget/take_attendance_screen_test.dart`.

## 7. Cài đặt

1. Firebase console: tạo project → thêm app Android package **`vn.edu.fpt.myfap_sim`** → tải `google-services.json`
   vào `android/app/`.
2. Authentication → Sign-in method → bật **Email/Password**.
3. Firestore Database → tạo database ở **test mode**.
4. Nạp dữ liệu mẫu: `dart run tool/seed.dart`
5. Khoá quyền: dán `firebase/firestore.rules` vào tab Rules của Firestore, hoặc
   `firebase deploy --only firestore:rules --project <project-id>`.
   Chạy lại seed về sau: chuyển Rules về test mode, seed, rồi dán lại rules.
6. Chạy: `flutter run` (Android). Bản release: `flutter build apk --release`.
   Build Android cần **NDK 28.2.13676358**. Nếu Gradle báo không cài được NDK, mở Android Studio → SDK Manager →
   SDK Tools → NDK (Side by side) để cài; thư mục SDK `C:\Android\Sdk` cần quyền ghi (chạy Android Studio bằng quyền admin).

```bash
flutter pub get
flutter analyze
flutter test
```
