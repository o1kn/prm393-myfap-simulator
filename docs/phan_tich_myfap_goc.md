# Phân tích ứng dụng gốc myFAP 2.0.5

Nguồn: `Du_an_nhom/myfap-2-0-5.xapk` (package `com.fuct`). Mở APK gốc `com.fuct.apk`, dịch ngược file
`assets/index.android.bundle` (Hermes bytecode v96, React Native) bằng `hermes-dec`, rồi đọc tên màn hình,
URL API, tham số, tên trường dữ liệu và bộ chuỗi giao diện tiếng Việt/Anh.

Ký hiệu: không đánh dấu = đọc được trực tiếp trong bundle; **[Suy luận]** = kết luận rút ra, không có trong bundle.

## 1. myFAP là gì

myFAP **không phải hệ thống quản lý đào tạo**. Nó là ứng dụng khách (client) chỉ đọc của hệ thống **FAP**
(`https://fap.fpt.edu.vn`). Toàn bộ dữ liệu nằm trên máy chủ FAP, ứng dụng gọi REST API
`https://api.fpt.edu.vn/fap/api/MyFAP/*` để xem.

Chỉ có **2 loại tài khoản** (`TYPE_ACCOUNT`):

| Loại | Đăng nhập | Ghi chú |
|---|---|---|
| `student` – Sinh viên | Google / FeID (`AuthenticationByGoogleAccessToken`, `AuthenticationByFeId`), chọn campus trước | Thấy toàn bộ chức năng |
| `donor` – Phụ huynh | Tên đăng nhập + mật khẩu (`AuthenticationByUsername`) | Xem thông tin học tập của con, nhận thông báo riêng (`GetNotificationByDonor`) |

Cán bộ đào tạo, giảng viên, trưởng bộ môn **không có** trong app mobile. Họ tạo ra dữ liệu (lịch, điểm danh,
điểm, xử lý đơn, thông báo) trên web FAP; sinh viên chỉ xem kết quả trên myFAP.

## 2. Kiến trúc của ứng dụng gốc

```
Màn hình (class component)
   │  gọi hàm service: getScheduleExam(), getMarkByCourse(), ...
   ▼
Tầng service API (axios)  ── thêm campusCode, rollNumber, Authen, checksum (HMAC-SHA256)
   │                          bản v2 qua https://fap-proxy.fpt.edu.vn dùng Bearer token,
   │                          401 → phát sự kiện "v2_session_expired" → về màn đăng nhập
   ▼
Máy chủ FAP (REST, JSON)

Phiên đăng nhập lưu bằng AsyncStorage: AUTHEN_KEY, ROLL_NUMBER, CAMPUS, EMAIL, FULL_NAME,
TYPE_ACCOUNT, SEMESTER_CAMPUS, DATA_SUBJECTS, BALANCE.
Thông báo đẩy: Firebase Cloud Messaging (UpdateTokedevices / UpdateTokenDonor lưu token thiết bị).
Đa ngôn ngữ: vi / en. Theme: ThemeContext, màu chủ đạo #1a2e4a (xanh navy) + #f39200 (cam FPT).
```

Điểm rút ra cho đồ án:

1. Đây là mô hình **client – server**. Mọi vai trò dùng chung một nguồn dữ liệu trên server.
2. Tầng UI **không** tự giữ dữ liệu nghiệp vụ; nó gọi tầng service/repository, service gọi server.
3. Phiên đăng nhập (token, mã SV, loại tài khoản) được lưu cục bộ để tự đăng nhập lại.

## 3. Điều hướng và màn hình

```
Splash → Chọn campus / Đăng nhập (Google-FeID hoặc phụ huynh)
  └─ Bottom tab (3 tab)
      ├─ Main (Stack)
      │   ├─ MainpageScreen          Trang chủ: lưới chức năng theo 5 nhóm (mục 4)
      │   ├─ ScheduleWeekScreen      Lịch học theo tuần
      │   ├─ ScheduleScreen          Lịch học theo kỳ
      │   ├─ ScheduleExamScreen      Lịch thi
      │   ├─ AttendanceScreen        Điểm danh theo môn → DetailsAttendanceScreen
      │   ├─ ResultScreen            Điểm học kỳ        → DetailsMarkScreen
      │   ├─ AcademicTranscriptScreen Bảng điểm toàn khoá
      │   ├─ FeeScreen               Học phí
      │   ├─ ApplicationScreen       Đơn từ (trạng thái)
      │   ├─ NotifiScreen            Thông báo
      │   ├─ NewsScreen              Tin tức            → DetailsNewsScreen
      │   ├─ TrainingScreen          Điểm rèn luyện
      │   ├─ ContactScreen           Liên hệ campus
      │   └─ RateScreen              Đánh giá dịch vụ
      ├─ MessagesScreen              Tin nhắn (thông báo đẩy đã nhận)
      └─ ProfileScreen               Thông tin sinh viên, phụ huynh, đăng xuất
```

## 4. Nhóm chức năng trên trang chủ

| Nhóm (chuỗi gốc) | Chức năng |
|---|---|
| Thông báo, đơn từ | Thông báo, Đơn từ |
| Lịch học, lịch thi | Lịch học (tuần), Lịch học theo kỳ, Lịch thi |
| Điểm danh, điểm, học phí | Điểm danh, Điểm học kỳ, Bảng điểm, Học phí |
| Các thông tin khác | Bản tin, Điểm rèn luyện, Liên hệ |
| Đánh giá dịch vụ / Thanh toán điện tử | Đánh giá dịch vụ, liên kết thanh toán học phí |

Ngoài ra, khi vào trang chủ app kiểm tra: có đợt **feedback giảng viên** đang mở không (`CheckOpenFeedBack`,
`GetStudentFeedbackForm`, `SubmitStudentFeedback`), có khảo sát bắt buộc không, có cần cập nhật hồ sơ không.

## 5. API và dữ liệu theo nghiệp vụ

Mọi API đều nhận `campusCode`, `Authen` (khoá phiên) và `checksum`. Cột "Trường" là tên trường màn hình đọc từ JSON.

| Nghiệp vụ | API | Tham số thêm | Trường dữ liệu chính |
|---|---|---|---|
| Đăng nhập | `AuthenticationByGoogleAccessToken`, `AuthenticationByFeId`, `AuthenticationByUsername` | `token` / `userName`, `Password` | rollNumber, fullName, email, typeAcc |
| Học kỳ | `GetSemester`, `GetWeekByDate` | `date` | semesterName, startDate, endDate |
| Lịch học tuần | `GetActivityStudentByWeek`, `GetActivityStudent` | `Semester` | date, slot, slotTime, roomNo, subjectCode, sessionNo, groupName, lecturer, **attendanceStatus**, isOnline, meetURL, material |
| Lịch thi | `GetScheduleExam` | `Semester` | realSubject, date, time, roomNo, kythi (FE/PE/lần thi), note |
| Điểm danh | `GetStudentAttendances`, `getCourseAttendance` | `Semester`, `SubjectCode`, `ClassName` | subjectCode, groupName, numberOfAttendances, numberOfTakenAttendances; chi tiết: date, slot, lecturer, attendanceStatus |
| Điểm học kỳ | `GetCourseOfSemester`, `GetStudentMark`, `GetSemesterMark`, `GetMarkByCourse` | `semester`, `CourseId` | subjectCode, subjectName, className, averageMark, status; chi tiết `resultDetails` (bảng điểm thành phần) |
| Bảng điểm | `AcademicTranscript` | – | toàn bộ môn theo kỳ, điểm TB, trạng thái |
| Môn học | `GetSubjets`, `GetSubjectBySemester` | `Semester` | subjectCode, subjectName |
| Học phí | `GeFeeByRoll`, `GetBalance` | – | termName, invoiceNo, invoiceDate, amount, note; balance |
| Đơn từ | `GetApplication` | – | type, createDate, status |
| Thông báo / tin | `GetNotificationByRoll`, `GetNotificationByDonor`, `GetTop10News`, `SearchNews` | `type`, `keysearch` | tittle, content, createDate, file đính kèm |
| Điểm rèn luyện | `GetDiemphongtrao` | `semester` | total, rating (Xuất sắc…Yếu), TTHocTap, khen thưởng/kỷ luật, CLB, phong trào |
| Đánh giá dịch vụ | `GetStudentRate`, `AddRate` | `rateid`, `rateValue`, `rateComment` | serviceName, rateId, số sao, nhận xét |
| Hồ sơ | `GetStudentById`, `RetriveImage`, `GetCampusInfo` | – | ngày sinh, giới tính, địa chỉ, chuyên ngành, kỳ hiện tại, phụ huynh, trạng thái học |
| Thiết bị | `UpdateTokedevices`, `UpdateTokenDonor` | `tokendevice` | token FCM |

### Trạng thái (enum) đọc được

| Đối tượng | Giá trị |
|---|---|
| Điểm danh một buổi | `present` (có mặt), `absent` (vắng), `not yet` (chưa diễn ra) |
| Kết quả môn | `passed`, `not passed`, đang học |
| Đơn từ | Đang xử lý, Đã được chấp nhận, Đã bị từ chối, Hủy, Đang chờ thanh toán, Khác |
| Xếp loại rèn luyện | Xuất sắc, Tốt, Khá, Trung bình khá, Trung bình, Yếu |
| Loại kỳ thi | FE, PE, thi lại (lần thi) |

## 6. Đối chiếu với đề bài và bản đã làm

Đề (PRM393_FA26.xlsx): *"Ứng dụng giả lập MyFAP – role cán bộ quản lý đào tạo, giảng viên, trưởng khoa/bộ môn,
sinh viên"*, được phép tự xây back-end; test case phải đi từ đầu đến cuối một quy trình nghiệp vụ và là kịch bản demo.

Bản đã làm hôm qua sai ở ba chỗ:

| Vấn đề | Bằng chứng | Vì sao sai |
|---|---|---|
| Nghiệp vụ lõi không có trong myFAP | Chức năng chính là "quản lý môn học" (thêm/sửa/xoá/duyệt môn) + giỏ đăng ký ≤ 20 tín chỉ, bê từ ví dụ "quản lý sản phẩm" Module 5 | myFAP xoay quanh **lịch học → điểm danh → điểm → đơn từ → thông báo**. Không có giỏ hàng, không có duyệt môn |
| README và code nói hai kiến trúc khác nhau | README: Clean Architecture 3 lớp + BLoC + go_router; code thật: Provider, `models/providers/screens`; 9 feature chỉ có thư mục `.gitkeep` rỗng | Thiết kế không khớp sản phẩm (rubric: *"Programs comply with the proposed design"*) |
| Không có nguồn dữ liệu chung | Dữ liệu nằm trong `InMemory` repository của từng lần chạy | myFAP là client–server. 4 vai trò cần **cùng một dữ liệu**: giảng viên điểm danh thì sinh viên phải thấy |

## 7. Hệ quả cho bản giả lập

**[Suy luận]** Bản giả lập phải bổ sung phần mà myFAP không có: các vai trò **tạo** dữ liệu (tương ứng web FAP),
còn phía sinh viên bám sát màn hình myFAP gốc.

| Vai trò | Việc làm (tạo dữ liệu) | Dữ liệu sinh viên thấy trên myFAP |
|---|---|---|
| Cán bộ quản lý đào tạo | Mở học kỳ, tạo lớp môn, xếp lịch (ngày, slot, phòng), xếp sinh viên vào lớp, xếp lịch thi, đăng thông báo, xử lý đơn từ | Lịch học, lịch thi, thông báo, trạng thái đơn |
| Trưởng bộ môn | Phân công giảng viên cho lớp thuộc bộ môn, duyệt công bố bảng điểm lớp, xem kết quả feedback giảng viên | Tên giảng viên trên lịch, điểm được công bố |
| Giảng viên | Xem lịch dạy, điểm danh từng buổi, nhập điểm thành phần, gửi bảng điểm | Trạng thái điểm danh, % vắng, điểm |
| Sinh viên | Xem lịch/điểm danh/điểm/bảng điểm/thông báo, gửi đơn, feedback giảng viên | – |

Quy trình nghiệp vụ xuyên suốt dùng làm system test và kịch bản demo:

```
Cán bộ ĐT mở kỳ + tạo lớp + xếp lịch + xếp SV
   → Trưởng BM phân công giảng viên
   → Giảng viên điểm danh các buổi        → SV thấy present/absent, % vắng (vắng > 20% → không đủ điều kiện thi)
   → Giảng viên nhập điểm, gửi duyệt
   → Trưởng BM duyệt công bố              → SV thấy điểm TB, passed / not passed, bảng điểm
SV gửi đơn → Cán bộ ĐT duyệt / từ chối    → SV thấy trạng thái đơn
Cán bộ ĐT đăng thông báo                  → SV / GV thấy thông báo
```

Ngưỡng vắng 20% và điều kiện qua môn (TB ≥ 5, không có đầu điểm 0) là quy chế FPT phổ biến, **[Suy luận]** không có trong bundle.

### 7.1 Màn hình bản giả lập thêm mà myFAP gốc không có

myFAP gốc là app sinh viên **chỉ để xem**; ba vai trò còn lại tương ứng phần web FAP mà bundle không chứa. Các màn hình
dưới đây vì vậy lấy mô hình từ web FAP (tài liệu nghiệp vụ + quy trình đào tạo), không phải từ bundle:

| Màn hình (bản giả lập) | Vai trò | Mô hình lấy từ |
|---|---|---|
| Lớp môn & lịch học: mở lớp, xếp lịch, kiểm tra trùng phòng | Cán bộ ĐT | web FAP – màn "Lớp môn" |
| Chi tiết lớp: sĩ số, lịch, danh sách sinh viên, **ghi danh bổ sung** | Cán bộ ĐT | web FAP – chi tiết lớp + danh sách sinh viên |
| Quản lý tài khoản: mở tài khoản sinh viên / giảng viên (mã giữ chỗ toàn cục) | Cán bộ ĐT | web FAP – quản lý người dùng |
| Phân công giảng viên theo bộ môn | Trưởng bộ môn | web FAP – phân công giảng dạy |
| Nhập điểm theo lớp + gửi duyệt; duyệt công bố / trả lại kèm lý do | Giảng viên, Trưởng bộ môn | web FAP – bảng điểm lớp |
| Điểm danh từng buổi (chỉ buổi chưa tới, lớp chưa công bố) | Giảng viên | web FAP – điểm danh buổi học |

Hai điểm khác biệt có chủ ý so với myFAP gốc, vì gốc không có phần "tạo dữ liệu":

1. **Ghi danh muộn**: chỉ thêm sinh viên vào buổi chưa tới và chưa điểm danh — không bịa điểm danh quá khứ, nên tỉ lệ vắng
   của sinh viên vào muộn tính trên đúng số buổi họ còn học được (khác cách tính `numberOfTakenAttendances` của gốc, vốn
   luôn tính trên toàn bộ buổi của lớp).
2. **Cảnh báo mất dữ liệu**: màn nhập điểm / điểm danh chặn back khi còn thay đổi chưa lưu — gốc là app chỉ xem nên không có
   tình huống này.
