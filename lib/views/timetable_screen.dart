import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/models/app_user.dart';
import '../data/models/class_session.dart';
import '../data/repositories/academic_repository.dart';
import '../viewmodels/timetable_view_model.dart';
import 'lecturer/take_attendance_screen.dart';
import 'widgets/common.dart';

final _dayFormat = DateFormat('dd/MM');
const _weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];

/// Weekly timetable. Sinh viên: lịch học + trạng thái điểm danh.
/// Giảng viên: lịch dạy, chạm vào buổi để điểm danh.
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          TimetableViewModel(context.read<AcademicRepository>(), user)..load(),
      child: const _TimetableView(),
    );
  }
}

class _TimetableView extends StatelessWidget {
  const _TimetableView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TimetableViewModel>();
    final today = DateUtils.dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(vm.isStudent ? 'Lịch học' : 'Lịch dạy'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: vm.load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Tuần trước',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: vm.previousWeek,
                ),
                Expanded(
                  child: TextButton(
                    onPressed: vm.currentWeek,
                    child: Text(
                      'Tuần ${_dayFormat.format(vm.weekStart)} - '
                      '${_dayFormat.format(vm.weekEnd)}',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tuần sau',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: vm.nextWeek,
                ),
              ],
            ),
          ),
          if (vm.busy) const LinearProgressIndicator(),
          if (vm.error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(vm.error!)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final (day, sessions) in vm.days) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                      '${_weekdays[day.weekday - 1]} ${_dayFormat.format(day)}'
                      '${day == today ? ' · Hôm nay' : ''}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (sessions.isEmpty)
                    Text(
                      'Không có lịch',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  for (final s in sessions)
                    _SessionCard(session: s, user: vm.user, onChanged: vm.load),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.user,
    required this.onChanged,
  });

  final ClassSession session;
  final AppUser user;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final isStudent = user.role == UserRole.student;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: isStudent
            ? null
            : () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TakeAttendanceScreen(session: session),
                  ),
                );
                await onChanged();
              },
        leading: CircleAvatar(child: Text('${session.slot}')),
        title: Text(
          '${session.subjectCode} - ${session.classCode}',
          style: text.titleSmall,
        ),
        subtitle: Text(
          '${session.slotTime} · Phòng ${session.room} · Buổi ${session.sessionNo}\n'
          'GV: ${session.lecturerName ?? 'chưa phân công'}',
        ),
        isThreeLine: true,
        trailing: isStudent
            ? StatusChip.attendance(session.statusOf(user.uid))
            : Icon(
                session.taken ? Icons.check_circle : Icons.chevron_right,
                color: session.taken ? Colors.green : null,
              ),
      ),
    );
  }
}
