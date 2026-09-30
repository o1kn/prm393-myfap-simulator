import '../data/models/class_session.dart';

/// Sinh [count] ngày học bắt đầu từ [start], chỉ rơi vào các thứ trong
/// [weekdays] (DateTime.monday = 1 … DateTime.sunday = 7).
List<DateTime> generateStudyDates(
  DateTime start,
  Set<int> weekdays,
  int count,
) {
  if (weekdays.isEmpty) {
    throw ArgumentError.value(weekdays, 'weekdays', 'Chọn ít nhất một thứ');
  }
  final dates = <DateTime>[];
  var day = DateTime(start.year, start.month, start.day);
  while (dates.length < count) {
    if (weekdays.contains(day.weekday)) dates.add(day);
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return dates;
}

/// Tìm buổi bị trùng: cùng ngày, cùng slot và cùng phòng. Trả về mô tả
/// các buổi trùng (rỗng = không trùng).
List<String> findRoomConflicts(
  Iterable<ClassSession> planned,
  Iterable<ClassSession> existing,
) {
  final taken = {
    for (final s in existing) '${s.dateKey}|${s.slot}|${s.room}': s,
  };
  return [
    for (final p in planned)
      if (taken['${p.dateKey}|${p.slot}|${p.room}'] case final other?)
        'Phòng ${p.room} slot ${p.slot} ngày ${p.dateKey} đã có lớp '
            '${other.subjectCode} - ${other.classCode}',
  ];
}

/// Ngày thứ Hai của tuần chứa [date].
DateTime mondayOf(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}
