import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_exception.dart';
import '../../core/constants.dart';
import '../../domain/schedule_rules.dart';
import '../models/app_user.dart';
import '../models/class_session.dart';
import '../models/course_class.dart';
import '../models/subject.dart';

/// Môn học, lớp môn, lịch học và điểm danh.
class AcademicRepository {
  AcademicRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _subjects =>
      _db.collection(Collections.subjects);
  CollectionReference<Map<String, dynamic>> get _classes =>
      _db.collection(Collections.classes);
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection(Collections.sessions);

  // ---------- Môn học ----------

  Future<List<Subject>> subjects() async {
    final snap = await _subjects.get();
    return snap.docs.map((d) => Subject.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  Future<Map<String, Subject>> subjectsByCode() async => {
    for (final s in await subjects()) s.code: s,
  };

  // ---------- Lớp môn ----------

  Future<List<CourseClass>> classesOfStudent(String uid) =>
      _queryClasses(_classes.where('studentIds', arrayContains: uid));

  Future<List<CourseClass>> classesOfLecturer(String uid) =>
      _queryClasses(_classes.where('lecturerId', isEqualTo: uid));

  Future<List<CourseClass>> classesOfDepartment(String department) =>
      _queryClasses(_classes.where('department', isEqualTo: department));

  Future<List<CourseClass>> allClasses() => _queryClasses(_classes);

  Future<CourseClass> classById(String id) async {
    final doc = await _classes.doc(id).get();
    return CourseClass.fromMap(doc.id, doc.data()!);
  }

  Future<List<CourseClass>> _queryClasses(
    Query<Map<String, dynamic>> query,
  ) async {
    final snap = await query.get();
    return snap.docs.map((d) => CourseClass.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  /// Cán bộ đào tạo mở lớp môn và xếp lịch trong một lần ghi (batch).
  /// Từ chối nếu trùng mã lớp của cùng môn trong kỳ, hoặc trùng phòng/slot.
  /// Trả về id lớp vừa tạo để màn hình mở chi tiết ngay sau khi tạo.
  Future<String> createClassWithSchedule({
    required Subject subject,
    required String classCode,
    required List<String> studentIds,
    required DateTime startDate,
    required Set<int> weekdays,
    required int slot,
    required String room,
  }) async {
    final code = classCode.trim().toUpperCase();
    final duplicate = await _classes
        .where('semester', isEqualTo: currentSemester)
        .where('subjectCode', isEqualTo: subject.code)
        .where('code', isEqualTo: code)
        .get();
    if (duplicate.docs.isNotEmpty) {
      throw AppException('Lớp ${subject.code} - $code đã tồn tại trong kỳ');
    }

    final classRef = _classes.doc();
    final dates = generateStudyDates(
      startDate,
      weekdays,
      subject.totalSessions,
    );
    final planned = [
      for (var i = 0; i < dates.length; i++)
        ClassSession(
          id: _sessions.doc().id,
          classId: classRef.id,
          classCode: code,
          subjectCode: subject.code,
          sessionNo: i + 1,
          date: dates[i],
          slot: slot,
          room: room.trim().toUpperCase(),
          studentIds: studentIds,
        ),
    ];

    final conflicts = findRoomConflicts(
      planned,
      await _sessionsOnDates(planned.map((s) => s.dateKey).toSet().toList()),
    );
    if (conflicts.isNotEmpty) throw AppException(conflicts.first);

    final batch = _db.batch()
      ..set(
        classRef,
        CourseClass(
          id: classRef.id,
          code: code,
          subjectCode: subject.code,
          subjectName: subject.name,
          semester: currentSemester,
          department: subject.department,
          studentIds: studentIds,
        ).toMap(),
      );
    for (final s in planned) {
      batch.set(_sessions.doc(s.id), s.toMap());
    }
    await batch.commit();
    return classRef.id;
  }

  /// Trưởng bộ môn phân công giảng viên: cập nhật lớp và mọi buổi của lớp
  /// để lịch dạy / lịch học hiện đúng tên giảng viên.
  Future<void> assignLecturer(CourseClass course, AppUser lecturer) async {
    if (lecturer.department != course.department) {
      throw const AppException('Giảng viên không thuộc bộ môn của lớp');
    }
    final sessions = await sessionsOfClass(course.id);
    final update = {'lecturerId': lecturer.uid, 'lecturerName': lecturer.code};
    final batch = _db.batch()..update(_classes.doc(course.id), update);
    for (final s in sessions) {
      batch.update(_sessions.doc(s.id), update);
    }
    await batch.commit();
  }

  /// Cán bộ đào tạo thêm sinh viên đã có tài khoản vào lớp.
  /// Chỉ cho phép khi bảng điểm còn `draft` / `returned`; trạng thái được
  /// đọc lại trong transaction nên cuộc gửi duyệt chen ngang sẽ bị từ chối.
  /// Sinh viên chỉ được ghi danh vào buổi chưa tới và chưa điểm danh
  /// (`!date.isBefore(today)` trước, `attendance` rỗng sau); buổi đã qua
  /// hoặc đã điểm danh giữ nguyên, không bịa điểm danh quá khứ. Giữ mọi id
  /// cũ bằng `arrayUnion`. Trả về số buổi đã ghi danh thêm.
  Future<int> enrollExistingStudent({
    required String classId,
    required String studentUid,
  }) async {
    final classRef = _classes.doc(classId);
    final existing = await classRef.get();
    final existingData = existing.data();
    if (existingData == null) {
      throw const AppException('Không tìm thấy lớp');
    }
    final course = CourseClass.fromMap(existing.id, existingData);
    _requireEnrollable(course);
    if (course.studentIds.contains(studentUid)) {
      throw const AppException('Sinh viên đã có trong lớp');
    }
    if (course.studentIds.length >= 200) {
      throw const AppException('Lớp đã đủ 200 sinh viên');
    }
    final sessions = await sessionsOfClass(classId);
    if (sessions.isEmpty) {
      throw const AppException('Lớp chưa có lịch học');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targets = [
      for (final s in sessions)
        if (!s.date.isBefore(today) &&
            !s.taken &&
            !s.studentIds.contains(studentUid))
          s,
    ];

    return _db.runTransaction<int>((tx) async {
      // Firestore yêu cầu đọc hết trước khi ghi trong một transaction, nên
      // đọc lớp + mọi buổi trước rồi mới ghi.
      final fresh = await tx.get(classRef);
      final freshData = fresh.data();
      if (freshData == null) {
        throw const AppException('Không tìm thấy lớp');
      }
      final freshCourse = CourseClass.fromMap(fresh.id, freshData);
      _requireEnrollable(freshCourse);
      if (freshCourse.studentIds.contains(studentUid)) {
        throw const AppException('Sinh viên đã có trong lớp');
      }
      final reads = [
        for (final s in targets) (s, await tx.get(_sessions.doc(s.id))),
      ];

      tx.update(classRef, {
        'studentIds': FieldValue.arrayUnion([studentUid]),
      });
      var added = 0;
      for (final (s, snap) in reads) {
        final data = snap.data();
        if (data == null) {
          throw AppException('Không tìm thấy buổi ${s.sessionNo} của lớp');
        }
        final attendance = Map<String, dynamic>.from(
          data['attendance'] as Map? ?? const {},
        );
        if (attendance.isNotEmpty) continue;
        final ids = List<String>.from(data['studentIds'] as List);
        if (ids.contains(studentUid)) continue;
        tx.update(_sessions.doc(s.id), {
          'studentIds': FieldValue.arrayUnion([studentUid]),
        });
        added++;
      }
      return added;
    });
  }

  void _requireEnrollable(CourseClass course) {
    switch (course.gradeStatus) {
      case GradeStatus.draft:
      case GradeStatus.returned:
        return;
      case GradeStatus.submitted:
        throw const AppException('Lớp đã gửi duyệt, không thể thêm sinh viên');
      case GradeStatus.published:
        throw const AppException(
          'Lớp đã công bố điểm, không thể thêm sinh viên',
        );
    }
  }

  // ---------- Buổi học & điểm danh ----------

  Future<List<ClassSession>> sessionsOfStudent(String uid) =>
      _querySessions(_sessions.where('studentIds', arrayContains: uid));

  Future<List<ClassSession>> sessionsOfLecturer(String uid) =>
      _querySessions(_sessions.where('lecturerId', isEqualTo: uid));

  Future<List<ClassSession>> sessionsOfClass(String classId) =>
      _querySessions(_sessions.where('classId', isEqualTo: classId));

  /// Buổi học của lớp theo góc nhìn giảng viên dạy lớp.
  ///
  /// Firestore chỉ cho truy vấn khi rules chứng minh được với chính bộ lọc
  /// của truy vấn: lọc mỗi `classId` thì nhánh `lecturerId == uid` không
  /// chứng minh được (bị PERMISSION_DENIED), nên phải lọc thêm `lecturerId`.
  Future<List<ClassSession>> sessionsOfLecturerInClass(
    String classId,
    String lecturerUid,
  ) => _querySessions(
    _sessions
        .where('classId', isEqualTo: classId)
        .where('lecturerId', isEqualTo: lecturerUid),
  );

  Future<List<ClassSession>> _sessionsOnDates(List<String> dateKeys) async {
    final result = <ClassSession>[];
    for (var i = 0; i < dateKeys.length; i += 30) {
      final end = i + 30 > dateKeys.length ? dateKeys.length : i + 30;
      result.addAll(
        await _querySessions(
          _sessions.where('date', whereIn: dateKeys.sublist(i, end)),
        ),
      );
    }
    return result;
  }

  Future<List<ClassSession>> _querySessions(
    Query<Map<String, dynamic>> query,
  ) async {
    final snap = await query.get();
    return snap.docs.map((d) => ClassSession.fromMap(d.id, d.data())).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.slot.compareTo(b.slot);
      });
  }

  Future<void> saveAttendance(
    String sessionId,
    Map<String, AttendanceStatus> attendance,
  ) => _sessions.doc(sessionId).update({
    'attendance': {for (final e in attendance.entries) e.key: e.value.name},
  });
}
