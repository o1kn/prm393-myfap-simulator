// Kiểm tra phân quyền trên Firebase thật (regression cho lỗi dời điểm sang lớp
// khác, ghi danh muộn và tài khoản mới). Chạy sau khi seed:
//
//   dart run tool/probe_rules.dart
//
// Mỗi dòng: gọi Firestore REST bằng ID token của một tài khoản, so kết quả với
// kỳ vọng. Thoát mã 1 nếu có dòng sai. Mọi doc thử được xoá bằng token quản
// trị (bỏ qua rules) nên dữ liệu seed không đổi.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const password = 'Myfap@2026';
late final String apiKey;
late final String base;

Future<void> main() async {
  final config = jsonDecode(
    File('android/app/google-services.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final projectId = config['project_info']['project_id'] as String;
  apiKey = config['client'][0]['api_key'][0]['current_key'] as String;
  base = 'https://firestore.googleapis.com/v1/projects/$projectId'
      '/databases/(default)/documents';

  final staff = await _signIn('daotao@myfap.vn');
  final son = await _signIn('sonnt@myfap.vn'); // GV lớp PRM393 (draft)
  final hung = await _signIn('hunglv@myfap.vn'); // GV lớp AI (đã công bố)
  final an = await _signIn('he170001@myfap.vn');
  final ha = await _signIn('he170002@myfap.vn');
  final bao = await _signIn('he170003@myfap.vn');
  final mine = 'prm393-se1943_${an.uid}';
  final victim = 'ail303m-ai1901_${an.uid}'; // điểm đã công bố của lớp khác
  final publishedSession = 'ail303m-ai1901-01'; // buổi của lớp đã công bố

  var failed = 0;
  Future<void> check(String name, int expected, Future<int> call) async {
    final got = await call;
    final ok = got == expected;
    if (!ok) failed++;
    print('${ok ? 'OK  ' : 'FAIL'} $name -> $got (mong đợi $expected)');
  }

  // ---------- Điểm ----------
  await check('GV tạo điểm ở lớp mình (draft)', 200,
      _put(son, 'grades/$mine', _grade('prm393-se1943', an.uid, false, 7)));
  await check('GV sửa điểm lớp mình', 200,
      _put(son, 'grades/$mine', _grade('prm393-se1943', an.uid, false, 8)));
  await check('GV tạo điểm ở lớp người khác', 403,
      _put(son, 'grades/ail303m-ai1901_x',
          _grade('ail303m-ai1901', an.uid, false, 9)));
  await check('DỜI điểm đã công bố của lớp khác sang lớp mình', 403,
      _put(son, 'grades/$victim', _grade('prm393-se1943', an.uid, false, 0)));
  await check('GV đúng lớp đổi classId của điểm sang lớp khác', 403,
      _put(hung, 'grades/$victim', _grade('swd392-se1944', an.uid, false, 0)));
  await check('GV đổi classId điểm của chính mình', 403,
      _put(son, 'grades/$mine', _grade('swd392-se1944', an.uid, false, 8)));
  await check('GV tự công bố điểm', 403,
      _put(son, 'grades/$mine', _grade('prm393-se1943', an.uid, true, 8)));

  // ---------- Điểm danh ----------
  final draftSession = 'prm393-se1943-20'; // buổi chưa tới của lớp draft
  await check('GV lớp draft lưu điểm danh buổi chưa tới (chỉ present/absent)',
      200,
      _put(son, 'sessions/$draftSession', {
        'attendance': {
          an.uid: 'present',
        },
      }));
  await check('GV lớp draft ghi trạng thái ngoài present/absent', 403,
      _put(son, 'sessions/$draftSession', {
        'attendance': {
          an.uid: 'late',
        },
      }));
  await check('GV ghi điểm danh lớp đã công bố', 403,
      _put(hung, 'sessions/$publishedSession', {
        'attendance': {
          an.uid: 'absent',
        },
      }));

  // ---------- Ghi danh muộn (cán bộ đào tạo) ----------
  final headSe = await _signIn('truongbm.se@myfap.vn'); // trưởng BM SE
  final tempClass = 'probe-class-${DateTime.now().millisecondsSinceEpoch}';
  final tempSession = '$tempClass-01';
  await check('Cán bộ ĐT mở lớp tạm (chưa có GV)', 200,
      _put(staff, 'classes/$tempClass', {
        'code': 'PROBE01',
        'subjectCode': 'PRM393',
        'subjectName': 'Mobile Programming',
        'semester': 'Fall2026',
        'department': 'SE',
        'studentIds': <String>[],
        'lecturerId': null,
        'lecturerName': null,
        'gradeStatus': 'draft',
        'headNote': '',
      }));
  await check('Cán bộ ĐT tạo buổi cho lớp tạm', 200,
      _put(staff, 'sessions/$tempSession', {
        'classId': tempClass,
        'classCode': 'PROBE01',
        'subjectCode': 'PRM393',
        'sessionNo': 1,
        'date': '2099-01-01',
        'slot': 4,
        'room': 'PROBE-1',
        'studentIds': <String>[],
        'lecturerId': null,
        'lecturerName': null,
        'attendance': <String, String>{},
      }));
  await check('Cán bộ ĐT ghi danh muộn vào lớp draft', 200,
      _put(staff, 'classes/$tempClass', {
        'studentIds': [an.uid],
      }));
  await check('Cán bộ ĐT thêm sinh viên vào buổi chưa tới', 200,
      _put(staff, 'sessions/$tempSession', {
        'studentIds': [an.uid],
      }));
  await check('Cán bộ ĐT ghi điểm danh (ngoài quyền)', 403,
      _put(staff, 'sessions/$tempSession', {
        'attendance': {
          an.uid: 'present',
        },
      }));
  await check('Trưởng BM SE phân công GV cho lớp tạm', 200,
      _put(headSe, 'classes/$tempClass', {
        'lecturerId': son.uid,
        'lecturerName': 'sonnt5',
      }));
  await check('GV dạy lớp tạm lưu điểm danh cho sinh viên ghi danh muộn', 200,
      _put(son, 'sessions/$tempSession', {
        'attendance': {
          an.uid: 'absent',
        },
      }));
  await check('GV lưu điểm danh cho người không có trong buổi', 403,
      _put(son, 'sessions/$tempSession', {
        'attendance': {
          hung.uid: 'absent',
        },
      }));
  await check('Cán bộ ĐT ghi danh thêm sinh viên khác vào lớp (vẫn draft)',
      200,
      _put(staff, 'classes/$tempClass', {
        'studentIds': [an.uid, ha.uid],
      }));
  await check('Cán bộ ĐT thay danh sách vừa thêm vừa bớt sinh viên', 403,
      _put(staff, 'classes/$tempClass', {
        'studentIds': [an.uid, bao.uid],
      }));
  await check('Cán bộ ĐT rút sinh viên khỏi lớp (bớt, không thêm)', 200,
      _put(staff, 'classes/$tempClass', {
        'studentIds': [an.uid],
      }));
  await check('Cán bộ ĐT ghi danh vào lớp đã công bố', 403,
      _put(staff, 'classes/ail303m-ai1901', {
        'studentIds': [an.uid],
      }));
  await check('Cán bộ ĐT đổi danh sách sinh viên của buổi lớp đã công bố', 403,
      _put(staff, 'sessions/$publishedSession', {
        'studentIds': [an.uid],
      }));

  // ---------- Tài khoản mới ----------
  final newUid = 'probe-uid-${DateTime.now().millisecondsSinceEpoch}';
  const newCode = 'PROBE999';
  await check('Cán bộ ĐT tạo hồ sơ sinh viên mới', 200,
      _put(staff, 'users/$newUid', {
        'role': 'student',
        'fullName': 'Probe Student',
        'code': newCode,
        'email': 'probe999@myfap.vn',
        'department': '',
      }));
  await check('Cán bộ ĐT đặt chỗ mã 3 trong userCodes', 200,
      _put(staff, 'userCodes/$newCode', {'uid': newUid}));
  await check('Đặt chỗ lại mã đã có (HE170001)', 403,
      _put(staff, 'userCodes/HE170001', {'uid': newUid}));
  await check('Cán bộ ĐT tạo hồ sơ vai trò staff', 403,
      _put(staff, 'users/${newUid}x', {
        'role': 'staff',
        'fullName': 'Probe Staff',
        'code': 'PROBE998',
        'email': 'probe998@myfap.vn',
        'department': '',
      }));
  await check('Giảng viên đọc mã người dùng', 403,
      _get(hung, 'userCodes/HE170001'));
  await check('Giảng viên tạo hồ sơ người dùng', 403,
      _put(hung, 'users/${newUid}y', {
        'role': 'student',
        'fullName': 'Probe Two',
        'code': 'PROBE997',
        'email': 'probe997@myfap.vn',
        'department': '',
      }));

  // ---------- Thông báo theo đối tượng ----------
  await check('Sinh viên đọc thông báo cho sinh viên', 200,
      _get(an, 'notifications/noti-1'));
  await check('Sinh viên đọc thông báo cho giảng viên', 403,
      _get(an, 'notifications/noti-2'));
  await check('Sinh viên đăng thông báo', 403,
      _put(an, 'notifications/probe-noti', {
        'title': 'Probe',
        'content': 'Probe',
        'audience': 'all',
        'createdAt': '2026-09-30T00:00:00.000',
        'authorName': 'Lê Minh An',
      }));

  // ---------- Đơn từ theo danh mục của FAP ----------
  await check('Sinh viên gửi đơn đúng danh mục màn "Đơn từ"', 200,
      _put(an, 'applications/probe-app', {
        'studentId': an.uid,
        'studentName': 'Lê Minh An',
        'studentCode': 'HE170001',
        'type': 'Xác nhận sinh viên',
        'content': 'Probe: xin giấy xác nhận sinh viên để mở thẻ.',
        'createdAt': '2026-09-30T00:00:00.000',
        'status': 'processing',
        'staffNote': '',
        'processedBy': '',
        'processedAt': null,
      }));
  await check('Sinh viên gửi đơn ngoài danh mục', 403,
      _put(an, 'applications/probe-app-2', {
        'studentId': an.uid,
        'studentName': 'Lê Minh An',
        'studentCode': 'HE170001',
        'type': 'Đăng ký muộn',
        'content': 'Probe: loại đơn không có trên màn Đơn từ.',
        'createdAt': '2026-09-30T00:00:00.000',
        'status': 'processing',
        'staffNote': '',
        'processedBy': '',
        'processedAt': null,
      }));

  // ---------- Truy vấn buổi học: rules chỉ cho khi bộ lọc chứng minh được ----
  // Firestore từ chối cả truy vấn nếu nhánh rules phụ thuộc trường không có
  // trong bộ lọc, nên app phải lọc thêm `lecturerId` cho giảng viên.
  await check('GV truy vấn buổi học chỉ theo classId', 403,
      _query(son, 'sessions', [
        _eq('classId', 'prm393-se1943'),
      ]));
  await check('GV truy vấn buổi học theo classId + lecturerId', 200,
      _query(son, 'sessions', [
        _eq('classId', 'prm393-se1943'),
        _eq('lecturerId', son.uid),
      ]));
  await check('Trưởng BM truy vấn buổi học theo classId', 200,
      _query(headSe, 'sessions', [
        _eq('classId', 'prm393-se1943'),
      ]));
  await check('Cán bộ ĐT truy vấn buổi học theo classId', 200,
      _query(staff, 'sessions', [
        _eq('classId', 'prm393-se1943'),
      ]));
  await check('SV truy vấn buổi học theo classId', 403,
      _query(an, 'sessions', [
        _eq('classId', 'prm393-se1943'),
      ]));
  await check('SV truy vấn buổi học của mình (array-contains uid)', 200,
      _query(an, 'sessions', [
        {
          'fieldFilter': {
            'field': {'fieldPath': 'studentIds'},
            'op': 'ARRAY_CONTAINS',
            'value': {'stringValue': an.uid},
          },
        },
      ]));

  // ---------- Dọn dẹp ----------
  for (final path in [
    'grades/$mine',
    'classes/$tempClass',
    'sessions/$tempSession',
    'users/$newUid',
    'users/${newUid}x',
    'users/${newUid}y',
    'userCodes/$newCode',
    'applications/probe-app',
    'applications/probe-app-2',
    'notifications/probe-noti',
  ]) {
    await http.delete(
      Uri.parse('$base/$path'),
      headers: {'Authorization': 'Bearer ${_adminToken()}'},
    );
  }
  // Trả buổi PRM393-20 về trạng thái seed (chưa điểm danh).
  await _putAdmin('sessions/$draftSession', {
    'attendance': <String, String>{},
  });
  print(failed == 0 ? 'Tất cả đúng.' : '$failed dòng sai.');
  exit(failed == 0 ? 0 : 1);
}

typedef _User = ({String token, String uid});

Future<_User> _signIn(String email) async {
  final r = await http.post(
    Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/'
      'accounts:signInWithPassword?key=$apiKey',
    ),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );
  final b = jsonDecode(r.body) as Map<String, dynamic>;
  return (token: b['idToken'] as String, uid: b['localId'] as String);
}

Map<String, dynamic> _grade(
  String classId,
  String studentId,
  bool published,
  double assignment,
) => {
  'classId': classId,
  'studentId': studentId,
  'studentCode': 'HE170001',
  'studentName': 'Lê Minh An',
  'subjectCode': 'PRM393',
  'semester': 'Fall2026',
  'published': published,
  'marks': {'Assignment': assignment},
};

/// Ghi các trường thô trong [fields] (updateMask), trả về mã HTTP.
/// Giá trị được bọc kiểu Firestore REST bằng [_value].
Future<int> _put(_User u, String path, Map<String, dynamic> fields) async {
  final mask = fields.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
  final r = await http.patch(
    Uri.parse('$base/$path?$mask'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${u.token}',
    },
    body: jsonEncode({
      'fields': {for (final e in fields.entries) e.key: _value(e.value)},
    }),
  );
  return r.statusCode;
}

/// Ghi bằng token quản trị (bỏ qua rules) để trả doc về trạng thái seed.
Future<void> _putAdmin(String path, Map<String, dynamic> fields) async {
  final mask = fields.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
  await http.patch(
    Uri.parse('$base/$path?$mask'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_adminToken()}',
    },
    body: jsonEncode({
      'fields': {for (final e in fields.entries) e.key: _value(e.value)},
    }),
  );
}

Future<int> _get(_User u, String path) async {
  final r = await http.get(
    Uri.parse('$base/$path'),
    headers: {'Authorization': 'Bearer ${u.token}'},
  );
  return r.statusCode;
}

Map<String, dynamic> _eq(String field, String value) => {
  'fieldFilter': {
    'field': {'fieldPath': field},
    'op': 'EQUAL',
    'value': {'stringValue': value},
  },
};

/// Chạy một structured query, trả về mã HTTP (200 = rules cho phép cả truy vấn).
Future<int> _query(
  _User u,
  String collection,
  List<Map<String, dynamic>> filters,
) async {
  final r = await http.post(
    Uri.parse('$base:runQuery'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${u.token}',
    },
    body: jsonEncode({
      'structuredQuery': {
        'from': [
          {'collectionId': collection},
        ],
        if (filters.length == 1)
          'where': filters.first
        else
          'where': {'compositeFilter': {'op': 'AND', 'filters': filters}},
      },
    }),
  );
  return r.statusCode;
}

/// Firestore REST chỉ nhận JSON có kiểu, và map rỗng phải là `mapValue`.
Object _value(Object? v) => switch (v) {
  null => {'nullValue': null},
  bool b => {'booleanValue': b},
  num n => n is int ? {'integerValue': '$n'} : {'doubleValue': n},
  String s => {'stringValue': s},
  List l => {
    'arrayValue': {
      'values': [for (final x in l) _value(x)],
    },
  },
  Map m => {
    'mapValue': {
      'fields': {for (final e in m.entries) e.key as String: _value(e.value)},
    },
  },
  _ => throw ArgumentError('Kiểu không hỗ trợ: $v'),
};

String _adminToken() {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']!;
  final f = File('$home/.config/configstore/firebase-tools.json');
  return (jsonDecode(f.readAsStringSync())['tokens']['access_token']) as String;
}