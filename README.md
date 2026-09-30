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
                                  grade sheet; student/, lecturer/, head/, staff/ (chi tiết lớp, quản lý tài khoản)
firebase/firestore.rules          Phân quyền theo vai trò trên máy chủ
tool/seed.dart                    Tạo tài khoản + dữ liệu mẫu trên Firebase
tool/probe_rules.dart             Gọi thẳng Firestore REST để kiểm phân quyền trên project thật
test/                             domain/ (quy tắc), workflow/ (quy trình 4 vai trò), widget/ (màn hình)
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
| `userCodes` | mã viết hoa | uid — giữ chỗ mã người dùng để không mở hai tài khoản cùng mã (cán bộ ĐT đọc/tạo) |

Quan hệ: `classes` 1–n `sessions`; `classes` 1–n `grades`; `subjects` 1–n `classes`; `users` n–n `classes` qua `studentIds`.
`studentIds` được chép sang `sessions` để sinh viên lấy lịch bằng một truy vấn `array-contains`.

Phân quyền (`firebase/firestore.rules`): sinh viên chỉ đọc điểm của mình khi `published == true` và chỉ đọc đơn của mình;
giảng viên chỉ sửa điểm danh buổi mình dạy (buổi chưa tới, lớp chưa công bố) và chỉ ghi điểm lớp mình khi bảng điểm ở
`draft`/`returned`; trưởng bộ môn chỉ thao tác lớp thuộc bộ môn; cán bộ đào tạo mở lớp, thêm/bớt sinh viên của lớp và
buổi chưa công bố, xử lý đơn, đăng thông báo, mở tài khoản sinh viên/giảng viên kèm giữ chỗ mã trong `userCodes`. Danh mục
`type` của đơn trong rules khớp đúng danh sách trên màn "Đơn từ"; thông báo chỉ đọc được theo đối tượng nhận.

## 4. Chức năng theo vai trò

| Vai trò | Chức năng |
|---|---|
| Cán bộ quản lý đào tạo | Mở lớp môn + xếp lịch cả kỳ (ngày bắt đầu, thứ, slot, phòng, sinh viên); xem chi tiết lớp (sĩ số, lịch, roster) và **ghi danh muộn** sinh viên đã có tài khoản vào các buổi chưa tới; xử lý đơn từ; đăng thông báo; **mở tài khoản sinh viên/giảng viên mới** |
| Trưởng bộ môn | Phân công giảng viên cho lớp thuộc bộ môn; duyệt bảng điểm: công bố hoặc trả lại kèm lý do |
| Giảng viên | Lịch dạy theo tuần; điểm danh từng buổi (chỉ buổi chưa tới, lớp chưa công bố); nhập điểm thành phần, lưu nháp, gửi duyệt; cảnh báo khi rời màn hình còn thay đổi chưa lưu |
| Sinh viên | Lịch học tuần kèm trạng thái điểm danh; báo cáo điểm danh toàn bộ môn (% vắng, số buổi còn lại trước ngưỡng 20%); điểm học kỳ; bảng điểm → mở thẳng điểm học kỳ và điểm danh của môn đó; gửi và theo dõi đơn |

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
| Đơn: nội dung ≥ 10 ký tự (≤ 2000); từ chối phải có lý do (≤ 1000); đơn đã xử lý không xử lý lại (transaction) | `application_repository.dart` |
| Ghi danh muộn: chỉ buổi chưa tới (`!date.isBefore(today)`) và chưa điểm danh, đọc lại trạng thái lớp trong transaction; buổi đã qua/đã điểm danh giữ nguyên (không bịa điểm danh quá khứ) | `academic_repository.dart::enrollExistingStudent` |
| Mã sinh viên/giảng viên giữ chỗ toàn cục trong `userCodes`, hồ sơ + giữ chỗ ghi trong một transaction | `user_repository.dart`, `viewmodels/staff/staff_accounts_view_model.dart` |
| Rời màn hình nhập điểm / điểm danh khi còn thay đổi chưa lưu → hỏi Lưu / Bỏ / Ở lại; lưu lỗi thì giữ nguyên thay đổi | `grade_sheet_view_model.dart`, `take_attendance_view_model.dart` |
| Truy vấn buổi học của giảng viên phải lọc theo `classId` **và** `lecturerId`: Firestore chỉ cho truy vấn khi rules chứng minh được bằng chính bộ lọc, lọc mỗi `classId` thì nhánh `lecturerId == uid` bị từ chối | `academic_repository.dart::sessionsOfLecturerInClass` |
| Thông báo chỉ hiện theo đối tượng nhận (`all` / `students` / `lecturers`) | `notification_repository.dart` + Firestore rules |

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

### Chạy thật bổ sung (30/09/2026)

Bốn chức năng thêm sau buổi chạy TC01–TC21 — chi tiết lớp + ghi danh muộn, quản lý tài khoản, cảnh báo chưa lưu, báo cáo
điểm danh theo môn — được chạy trên **cùng APK release + Firebase thật**:

| ID | Tài khoản | Các bước | Kết quả mong đợi | Ảnh |
|---|---|---|---|---|
| TC22 | daotao@myfap.vn | Lớp môn & lịch học → chạm lớp PRM393 | Chi tiết lớp: môn/kỳ/bộ môn/GV, sĩ số 5, 20 buổi kèm trạng thái điểm danh, danh sách sinh viên | [chi tiết](docs/demo/tc22_chi_tiet_lop.png), [roster](docs/demo/tc22_roster_ghi_danh.png) |
| TC23 | daotao@myfap.vn | Mở lớp AIL303m (đã công bố) | Nút "Thêm sinh viên" bị khoá, ghi rõ "Lớp đã công bố, không thể thêm sinh viên." | [tc23](docs/demo/tc23_lop_da_cong_bo.png) |
| TC24 | daotao@myfap.vn → he170005@myfap.vn | SWD392 → Thêm sinh viên → chọn Vũ Đức Huy (HE170005) → mở lại lịch tuần | Ghi danh 19 buổi sắp tới (buổi đã qua giữ nguyên); Firestore: `classes` + 19 buổi có uid mới, buổi 1 (29/09) **không** đổi; SV thấy SWD392 - SE1944 kèm "Chưa diễn ra" | [chọn SV](docs/demo/tc24_chon_sinh_vien.png), [roster 5 SV](docs/demo/tc22_roster_ghi_danh.png), [SV](docs/demo/tc03_sv_thay_lich.png) |
| TC25 | daotao@myfap.vn | Quản lý tài khoản → Tạo tài khoản: HE170001 (trùng mã) → đổi mã HE179999 → tạo; sau đó đăng nhập bằng tài khoản mới | Trùng mã: "Mã HE170001 đã tồn tại"; tạo xong: "Đã tạo tài khoản", phiên cán bộ ĐT không đổi; tài khoản mới đăng nhập vào thẳng Trang chủ | [danh sách](docs/demo/tc25_quan_ly_tai_khoan.png), [form](docs/demo/tc25_form_tao_tai_khoan.png), [trùng mã](docs/demo/tc25_trung_ma.png), [đã tạo](docs/demo/tc25_da_tao.png) |
| TC26 | sonnt@myfap.vn | Nhập điểm → PRM393 → nhập 8 cho HE170001 → back | Banner "Chưa lưu thay đổi", hộp thoại "Còn thay đổi chưa lưu" (Ở lại / Bỏ thay đổi / Lưu); chọn Lưu → "Đã lưu nháp" và về danh sách lớp | [chưa lưu](docs/demo/tc26_chua_luu.png), [hộp thoại](docs/demo/tc26_hoi_bo_thay_doi.png), [đã lưu](docs/demo/tc26_da_luu_nhap.png) |
| TC27 | hunglv@myfap.vn | Lịch dạy & điểm danh → buổi AIL303m hôm nay | "Lớp đã công bố: điểm danh chỉ xem, không thể sửa", không có công tắc và nút lưu | [tc27](docs/demo/tc27_diem_danh_lop_cong_bo.png) |
| TC28 | he170002@myfap.vn | Bảng điểm → chạm môn PRN212 → "Xem điểm danh môn này" | Mở thẳng Điểm học kỳ của PRN212 (TB 7.2, Passed) rồi Điểm danh của đúng môn đó; phần Tổng quan liệt kê mọi môn kèm "Vắng x/y" và "còn N buổi được phép vắng thêm" | [tổng quan](docs/demo/tc28_diem_danh_tong_quan.png), [bảng điểm](docs/demo/tc28_bang_diem.png), [điểm học kỳ](docs/demo/tc28_diem_hoc_ky.png), [điểm danh môn](docs/demo/tc28_diem_danh_theo_mon.png), [lịch dạy GV](docs/demo/tc28_lich_day_tuan.png) |
| TC29 | he170005@myfap.vn | Đổi máy sang 320dp + cỡ chữ hệ thống 2.0 → mở Trang chủ | Trước: nhãn ô số liệu bị cắt "Buổi học h…", "Đơn đang …". Sau: hai ô xếp dọc, nhãn đủ "Buổi học hôm nay", "Đơn đang xử lý"; máy thường (cỡ chữ 1.0) vẫn xếp ngang | [trước](docs/demo/tc29_man_hinh_nho_truoc.png), [sau](docs/demo/tc29_man_hinh_nho_sau.png) |

Mở lại app sau khi đã đăng nhập thì vào thẳng Trang chủ (Firebase Auth giữ phiên): [ảnh](docs/demo/gv_trang_chu_tu_dang_nhap.png).

Test tự động (41 test): `test/workflow/business_process_test.dart` (mở lớp → phân công → điểm danh → nhập điểm → trả lại →
công bố → SV xem; đơn từ), `test/domain/rules_test.dart`, `test/widget/` (điểm danh, form gửi đơn, còn thay đổi chưa lưu,
thông báo theo đối tượng nhận, dựng màn bảng điểm và lịch tuần, màn hình 320dp + chữ phóng to 2x).

### Kiểm tra phân quyền trên Firebase thật

Gọi thẳng Firestore REST bằng ID token của từng tài khoản (bỏ qua app), 30/09/2026:

| Thao tác | Kết quả |
|---|---|
| SV đọc điểm đã công bố của mình | Cho phép (200) |
| SV đọc điểm của SV khác / truy vấn toàn bộ điểm của lớp | Chặn (403) |
| SV tự đổi `role` thành `staff` | Chặn (403) |
| SV gửi đơn đứng tên SV khác / đọc đơn của SV khác / đăng thông báo | Chặn (403) |
| GV điểm danh lớp mình không dạy / sửa điểm lớp đã công bố | Chặn (403) |
| GV dời điểm đã công bố của lớp khác sang lớp mình (đổi `classId`, `published:false`) / GV đổi `classId` điểm | Chặn (403), doc nạn nhân không đổi |
| GV tạo điểm ở lớp người khác / tự đặt `published:true` | Chặn (403) |
| GV tạo và sửa điểm ở lớp mình đang `draft` | Cho phép (200) |
| Trưởng BM AI trả lại bảng điểm lớp bộ môn SE | Chặn (403) |
| Cán bộ ĐT xử lý lại đơn đã duyệt | Chặn (403) |
| Cán bộ ĐT ghi danh muộn vào lớp `draft` + buổi chưa tới | Cho phép (200) |
| Cán bộ ĐT ghi danh vào lớp đã công bố / đổi danh sách sinh viên của buổi lớp đã công bố | Chặn (403) |
| Cán bộ ĐT ghi điểm danh (ngoài quyền) | Chặn (403) |
| Cán bộ ĐT thay danh sách sinh viên vừa thêm vừa bớt (đổi roster) | Chặn (403); chỉ thêm hoặc chỉ bớt thì cho phép |
| GV lưu điểm danh cho người không có trong buổi | Chặn (403) |
| GV ghi điểm danh lớp đã công bố / ghi trạng thái ngoài `present`/`absent` | Chặn (403) |
| Cán bộ ĐT mở hồ sơ sinh viên/giảng viên + giữ chỗ mã mới | Cho phép (200) |
| Cán bộ ĐT mở hồ sơ vai trò `staff` / đặt chỗ lại mã đã có / GV đọc hoặc tạo hồ sơ người dùng | Chặn (403) |
| SV đọc thông báo cho giảng viên / SV đăng thông báo | Chặn (403) |
| SV gửi đơn ngoài danh mục trên màn "Đơn từ" | Chặn (403) |
| GV truy vấn buổi học chỉ theo `classId` (thiếu `lecturerId`) | Chặn (403) — app phải lọc thêm `lecturerId` |
| GV / trưởng BM / cán bộ ĐT truy vấn buổi học của một lớp | Cho phép (200) |
| SV truy vấn buổi học theo `classId` (không phải buổi của mình) | Chặn (403); truy vấn `array-contains` uid của mình thì cho phép (200) |

Regression: `dart run tool/probe_rules.dart` chạy lại 40 thao tác ở trên trên Firebase thật (mã thoát 1 nếu sai), tự dọn
mọi doc thử bằng token quản trị nên dữ liệu seed không đổi. Rule `grades` tách `create` / `update`; `update` xét quyền
theo `resource.data.classId` (lớp hiện có của bản ghi) và khoá `classId`, `studentId` không đổi.

Giới hạn đã biết: rules không kiểm tra được cán bộ ĐT có thêm sinh viên vào **đúng buổi chưa tới** hay không (ngày buổi học
lưu dạng chuỗi `yyyy-MM-dd`, không so được với giờ máy chủ). Phía máy chủ chỉ chặn đổi roster của lớp/buổi đã công bố; phần
"chỉ buổi chưa tới" do app thực hiện (`academic_repository.dart::enrollExistingStudent`) và được kiểm bằng test + probe.

### Lỗi tìm thấy khi chạy thật và cách sửa

Bốn lỗi chỉ lộ ra trên máy thật hoặc khi đổi cỡ chữ (test thường không thấy), đã sửa và khoá lại bằng test/probe:

| Lỗi | Nguyên nhân | Sửa |
|---|---|---|
| Bảng điểm trắng trơn, `Null check operator used on a null value` ở `GradeSheetViewModel.completeCount` | Truy vấn buổi học của giảng viên (`where classId`) bị rules từ chối → `sessions`/`marks` không tải, màn hình vẫn dựng | Thêm `sessionsOfLecturerInClass` (lọc thêm `lecturerId`), đọc điểm/buổi an toàn khi thiếu dữ liệu; probe kiểm luôn nhánh truy vấn |
| Lịch tuần trắng phần danh sách buổi (cả SV và GV) | `Row(crossAxisAlignment: stretch)` trong `ListView` → "BoxConstraints forces an infinite height", thẻ không dựng được | Bọc `IntrinsicHeight` cho `Row` của thẻ buổi học; test `timetable_render_test.dart` giữ lỗi không quay lại |
| Nhãn ô số liệu bị cắt "Buổi học h…" khi cỡ chữ hệ thống 2.0 trên màn nhỏ (chỉ lộ khi đổi cỡ chữ trên máy) | Hai `StatTile` cạnh nhau (mỗi ô ~ nửa chiều ngang) không đủ chỗ cho nhãn dài | Thêm `StatRow`: chữ phóng to từ 1.5 lần thì xếp dọc, còn lại xếp ngang; test kiểm nhãn không bị cắt |
| Màn Quản lý tài khoản (320dp, chữ 2x) tràn ngang; dòng cuối bị nút "Tạo tài khoản" che | Chip vai trò nằm ở `ListTile.trailing`, dropdown không `isExpanded`, đệm dưới 24 nhỏ hơn chiều cao nút | Chip chuyển xuống `subtitle`, dropdown `isExpanded` + cắt chữ bằng `…`, đệm dưới 88; `small_screen_test.dart` kiểm 13 màn hình không tràn |

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
