// Nạp dữ liệu mẫu lên Firebase của nhóm (xoá sạch dữ liệu cũ rồi tạo lại).
//
//   dart run tool/seed.dart
//
// Đọc apiKey / projectId từ android/app/google-services.json, tạo tài khoản
// Firebase Auth (email/password) cho 4 vai trò rồi ghi Firestore qua REST API.
//
// Dữ liệu được ghi bằng token OAuth của tài khoản đang `firebase login`
// (thành viên project). Request loại này được IAM cấp quyền và không đi qua
// firebase/firestore.rules — giống Admin SDK — nên KHÔNG phải mở rules khi
// nạp lại dữ liệu. Chạy lại ngay trước buổi demo để có buổi học "hôm nay".
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const password = 'Myfap@2026';
const semester = 'Fall2026';

late final String apiKey;
late final String projectId;
late final String adminToken;

Future<void> main() async {
  final config = jsonDecode(
    File('android/app/google-services.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  projectId = config['project_info']['project_id'] as String;
  apiKey = config['client'][0]['api_key'][0]['current_key'] as String;
  print('Project: $projectId');

  // ---------- Tài khoản ----------
  final people = <String, Map<String, String>>{
    'staff': _p('daotao', 'Nguyễn Thị Hoa', 'hoant', 'staff', ''),
    'headSE': _p('truongbm.se', 'Trần Văn Nam', 'namtv', 'head', 'SE'),
    'headAI': _p('truongbm.ai', 'Lê Thu Hằng', 'hanglt', 'head', 'AI'),
    'son': _p('sonnt', 'Ngô Tùng Sơn', 'sonnt5', 'lecturer', 'SE'),
    'lan': _p('lanpt', 'Phạm Thị Lan', 'lanpt', 'lecturer', 'SE'),
    'hung': _p('hunglv', 'Lê Văn Hùng', 'hunglv', 'lecturer', 'AI'),
    'an': _p('he170001', 'Lê Minh An', 'HE170001', 'student', ''),
    'ha': _p('he170002', 'Trần Thu Hà', 'HE170002', 'student', ''),
    'bao': _p('he170003', 'Phạm Quốc Bảo', 'HE170003', 'student', ''),
    'linh': _p('he170004', 'Đỗ Khánh Linh', 'HE170004', 'student', ''),
    'huy': _p('he170005', 'Vũ Đức Huy', 'HE170005', 'student', ''),
  };
  final uid = <String, String>{};
  for (final e in people.entries) {
    uid[e.key] = await _account(e.value['email']!);
  }
  adminToken = await _adminToken();

  for (final c in [
    'users',
    'subjects',
    'classes',
    'sessions',
    'grades',
    'applications',
    'notifications',
    'userCodes',
  ]) {
    await _clear(c);
  }

  for (final e in people.entries) {
    await _put('users', uid[e.key]!, e.value);
  }
  for (final e in people.entries) {
    await _put('userCodes', e.value['code']!.toUpperCase(), {
      'uid': uid[e.key]!,
    });
  }

  // ---------- Môn học ----------
  final components = [
    {'name': 'Assignment', 'weight': 20, 'isFinal': false},
    {'name': 'Progress Test', 'weight': 20, 'isFinal': false},
    {'name': 'Project', 'weight': 30, 'isFinal': false},
    {'name': 'Final Exam', 'weight': 30, 'isFinal': true},
  ];
  final subjects = {
    'PRM393': ('Mobile Programming', 'SE'),
    'SWD392': ('Software Architecture and Design', 'SE'),
    'PRN212': ('Basis Cross-Platform Application Programming With .NET', 'SE'),
    'AIL303m': ('Machine Learning', 'AI'),
  };
  for (final e in subjects.entries) {
    await _put('subjects', e.key, {
      'name': e.value.$1,
      'credits': 3,
      'department': e.value.$2,
      'totalSessions': 20,
      'components': components,
    });
  }

  // ---------- Lớp môn + lịch học ----------
  final today = DateTime.now();
  final monday = DateTime(
    today.year,
    today.month,
    today.day - today.weekday + 1,
  );
  final students = ['an', 'ha', 'bao', 'linh', 'huy'];

  // PRM393: đã phân công GV Sơn, học từ 3 tuần trước, 2 buổi/tuần slot 1.
  // Một buổi rơi đúng ngày chạy seed (chưa điểm danh) để demo điểm danh.
  // Bảo vắng 5/20 buổi (> 20%) để minh hoạ "không đủ điều kiện dự thi".
  await _class(
    id: 'prm393-se1943',
    code: 'SE1943',
    subject: 'PRM393',
    lecturer: ('son', people['son']!),
    students: [for (final s in students) uid[s]!],
    start: DateTime(monday.year, monday.month, monday.day - 21),
    weekdays: {today.weekday, (today.weekday + 1) % 7 + 1},
    slot: 1,
    room: 'BE-301',
    absences: {uid['bao']!: 5, uid['an']!: 1},
    uidOf: uid,
  );
  // SWD392: chưa phân công GV — trưởng BM SE phân công trong kịch bản demo.
  await _class(
    id: 'swd392-se1944',
    code: 'SE1944',
    subject: 'SWD392',
    lecturer: null,
    students: [
      for (final s in ['an', 'ha', 'bao', 'linh']) uid[s]!,
    ],
    start: monday,
    weekdays: {2, 5},
    slot: 2,
    room: 'BE-302',
    absences: const {},
    uidOf: uid,
  );
  // AIL303m: bộ môn AI, đã công bố điểm.
  await _class(
    id: 'ail303m-ai1901',
    code: 'AI1901',
    subject: 'AIL303m',
    lecturer: ('hung', people['hung']!),
    students: [uid['an']!, uid['ha']!],
    start: DateTime(monday.year, monday.month, monday.day - 14),
    weekdays: {3, 6},
    slot: 3,
    room: 'AL-R402',
    absences: const {},
    uidOf: uid,
    gradeStatus: 'published',
  );
  await _grade('ail303m-ai1901', 'AIL303m', people['an']!, uid['an']!, [
    8,
    7.5,
    8.5,
    7,
  ], published: true);
  await _grade('ail303m-ai1901', 'AIL303m', people['ha']!, uid['ha']!, [
    7,
    6,
    7,
    3,
  ], published: true);

  // PRN212 kỳ trước (Summer2026), đã công bố — để bảng điểm có lịch sử.
  await _put('classes', 'prn212-se1830', {
    'code': 'SE1830',
    'subjectCode': 'PRN212',
    'subjectName': subjects['PRN212']!.$1,
    'semester': 'Summer2026',
    'department': 'SE',
    'studentIds': [for (final s in students) uid[s]!],
    'lecturerId': uid['lan'],
    'lecturerName': people['lan']!['code'],
    'gradeStatus': 'published',
    'headNote': '',
  });
  for (final (i, s) in students.indexed) {
    await _grade(
      'prn212-se1830',
      'PRN212',
      people[s]!,
      uid[s]!,
      [7 + i * 0.5, 6.5, 8, 6 + i * 0.5],
      published: true,
      sem: 'Summer2026',
    );
  }

  // ---------- Đơn từ ----------
  await _put('applications', 'app-an-1', {
    'studentId': uid['an'],
    'studentName': people['an']!['fullName'],
    'studentCode': people['an']!['code'],
    'type': 'Xác nhận sinh viên',
    'content': 'Xin giấy xác nhận sinh viên để làm thẻ xe bus.',
    'createdAt': today.subtract(const Duration(days: 6)).toIso8601String(),
    'status': 'approved',
    'staffNote': 'Nhận giấy tại phòng P.102 sau 2 ngày làm việc.',
    'processedBy': people['staff']!['fullName'],
    'processedAt': today.subtract(const Duration(days: 5)).toIso8601String(),
  });
  await _put('applications', 'app-ha-1', {
    'studentId': uid['ha'],
    'studentName': people['ha']!['fullName'],
    'studentCode': people['ha']!['code'],
    'type': 'Xin chuyển lớp học',
    'content': 'Em xin chuyển từ SE1944 sang lớp khác vì trùng lịch làm thêm.',
    'createdAt': today.subtract(const Duration(days: 1)).toIso8601String(),
    'status': 'processing',
    'staffNote': '',
    'processedBy': '',
    'processedAt': null,
  });

  // ---------- Thông báo ----------
  await _put('notifications', 'noti-1', {
    'title': 'Lịch thi Progress Test kỳ $semester',
    'content': 'Sinh viên xem lịch thi Progress Test trên myFAP từ tuần sau.',
    'audience': 'students',
    'createdAt': today.subtract(const Duration(days: 2)).toIso8601String(),
    'authorName': people['staff']!['fullName'],
  });
  await _put('notifications', 'noti-2', {
    'title': 'Hạn nộp bảng điểm giữa kỳ',
    'content': 'Giảng viên hoàn thành nhập điểm và gửi trưởng bộ môn duyệt.',
    'audience': 'lecturers',
    'createdAt': today.subtract(const Duration(days: 3)).toIso8601String(),
    'authorName': people['staff']!['fullName'],
  });

  print('Xong. Mật khẩu mọi tài khoản: $password');
}

Map<String, String> _p(
  String user,
  String name,
  String code,
  String role,
  String dep,
) => {
  'email': '$user@myfap.vn',
  'fullName': name,
  'code': code,
  'role': role,
  'department': dep,
};

Future<void> _class({
  required String id,
  required String code,
  required String subject,
  required (String, Map<String, String>)? lecturer,
  required List<String> students,
  required DateTime start,
  required Set<int> weekdays,
  required int slot,
  required String room,
  required Map<String, int> absences,
  required Map<String, String> uidOf,
  String gradeStatus = 'draft',
}) async {
  final lecturerId = lecturer == null ? null : uidOf[lecturer.$1];
  final lecturerCode = lecturer?.$2['code'];
  final subjectName = await _get('subjects', subject);
  await _put('classes', id, {
    'code': code,
    'subjectCode': subject,
    'subjectName': subjectName['name'],
    'semester': semester,
    'department': subjectName['department'],
    'studentIds': students,
    'lecturerId': lecturerId,
    'lecturerName': lecturerCode,
    'gradeStatus': gradeStatus,
    'headNote': '',
  });

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final remaining = Map.of(absences);
  var day = start;
  for (var n = 1; n <= 20;) {
    if (weekdays.contains(day.weekday)) {
      // Buổi trước hôm nay đã điểm danh; hôm nay và sau đó chưa.
      final past = day.isBefore(todayDate) && lecturerId != null;
      final attendance = <String, String>{};
      if (past) {
        for (final s in students) {
          final left = remaining[s] ?? 0;
          attendance[s] = left > 0 ? 'absent' : 'present';
          if (left > 0) remaining[s] = left - 1;
        }
      }
      await _put('sessions', '$id-${n.toString().padLeft(2, '0')}', {
        'classId': id,
        'classCode': code,
        'subjectCode': subject,
        'sessionNo': n,
        'date': _dateKey(day),
        'slot': slot,
        'room': room,
        'studentIds': students,
        'lecturerId': lecturerId,
        'lecturerName': lecturerCode,
        'attendance': attendance,
      });
      n++;
    }
    day = DateTime(day.year, day.month, day.day + 1);
  }
}

Future<void> _grade(
  String classId,
  String subject,
  Map<String, String> student,
  String studentId,
  List<num> marks, {
  required bool published,
  String sem = semester,
}) => _put('grades', '${classId}_$studentId', {
  'classId': classId,
  'studentId': studentId,
  'studentName': student['fullName'],
  'studentCode': student['code'],
  'subjectCode': subject,
  'semester': sem,
  'marks': {
    'Assignment': marks[0],
    'Progress Test': marks[1],
    'Project': marks[2],
    'Final Exam': marks[3],
  },
  'published': published,
});

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------- Firebase REST ----------

Future<String> _account(String email) async {
  final body = jsonEncode({
    'email': email,
    'password': password,
    'returnSecureToken': true,
  });
  var res = await http.post(
    Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    ),
    body: body,
  );
  if (res.statusCode != 200 && res.body.contains('EMAIL_EXISTS')) {
    res = await http.post(
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
      ),
      body: body,
    );
  }
  if (res.statusCode != 200) {
    throw StateError('Auth $email: ${res.body}');
  }
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  print('  tài khoản $email');
  return json['localId'] as String;
}

/// Access token của tài khoản đang đăng nhập Firebase CLI. Chạy một lệnh CLI
/// bất kỳ để CLI tự làm mới token rồi ghi lại vào configstore.
Future<String> _adminToken() async {
  final r = await Process.run('firebase', [
    'projects:list',
    '--json',
  ], runInShell: true);
  if (r.exitCode != 0) {
    throw StateError(
      'Chạy `firebase login` bằng tài khoản có quyền trên project trước.',
    );
  }
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']!;
  final store = File('$home/.config/configstore/firebase-tools.json');
  final tokens = (jsonDecode(store.readAsStringSync()) as Map)['tokens'] as Map;
  return tokens['access_token'] as String;
}

String get _base =>
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

Map<String, String> get _headers => {
  'Authorization': 'Bearer $adminToken',
  'Content-Type': 'application/json',
};

Future<void> _put(
  String collection,
  String id,
  Map<String, dynamic> data,
) async {
  final res = await http.patch(
    Uri.parse('$_base/$collection/$id'),
    headers: _headers,
    body: jsonEncode({
      'fields': {for (final e in data.entries) e.key: _encode(e.value)},
    }),
  );
  if (res.statusCode != 200) {
    throw StateError('Ghi $collection/$id: ${res.body}');
  }
}

Future<Map<String, dynamic>> _get(String collection, String id) async {
  final res = await http.get(
    Uri.parse('$_base/$collection/$id'),
    headers: _headers,
  );
  final fields =
      (jsonDecode(res.body) as Map<String, dynamic>)['fields'] as Map;
  return {
    for (final e in fields.entries)
      e.key as String: (e.value as Map).values.first,
  };
}

Future<void> _clear(String collection) async {
  while (true) {
    final res = await http.get(
      Uri.parse('$_base/$collection?pageSize=300&mask.fieldPaths=__name__'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw StateError('Đọc $collection: ${res.body}');
    final docs =
        (jsonDecode(res.body) as Map<String, dynamic>)['documents'] as List?;
    if (docs == null || docs.isEmpty) return;
    for (final d in docs) {
      final name = (d as Map)['name'] as String;
      await http.delete(
        Uri.parse('https://firestore.googleapis.com/v1/$name'),
        headers: _headers,
      );
    }
    print('  xoá ${docs.length} bản ghi $collection');
  }
}

Map<String, dynamic> _encode(Object? v) => switch (v) {
  null => {'nullValue': null},
  bool b => {'booleanValue': b},
  int i => {'integerValue': '$i'},
  double d => {'doubleValue': d},
  String s => {'stringValue': s},
  List l => {
    'arrayValue': {
      'values': [for (final x in l) _encode(x)],
    },
  },
  Map m => {
    'mapValue': {
      'fields': {for (final e in m.entries) e.key as String: _encode(e.value)},
    },
  },
  _ => throw ArgumentError('Kiểu không hỗ trợ: $v'),
};
