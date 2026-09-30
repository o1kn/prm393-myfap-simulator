import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../data/models/app_user.dart';
import '../data/models/class_session.dart';
import '../data/repositories/academic_repository.dart';
import '../viewmodels/timetable_view_model.dart';
import 'lecturer/take_attendance_screen.dart';
import 'widgets/common.dart';

const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Lịch theo tuần. Sinh viên: lịch học + trạng thái điểm danh.
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
          // Chuyển tuần: giữ nguyên cạnh trái/phải, nhãn tuần ở giữa.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
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
                      'Tuần ${_two(vm.weekStart.day)}/${_two(vm.weekStart.month)}'
                      ' - ${_two(vm.weekEnd.day)}/${_two(vm.weekEnd.month)}',
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
          _DayBar(vm: vm, today: today),
          if (vm.busy) const LinearProgressIndicator(minHeight: 2),
          if (vm.error != null && vm.days.every((d) => d.$2.isEmpty))
            Padding(padding: const EdgeInsets.all(16), child: Text(vm.error!))
          else
            Expanded(
              child: AsyncBody(
                vm: vm,
                isEmpty: vm.days.every((d) => d.$2.isEmpty),
                emptyText: 'Tuần này không có buổi học',
                onRetry: vm.load,
                builder: (_) => _DayList(vm: vm, today: today),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thanh chọn ngày: mỗi ngày một ô vuông, chấm dưới ô nếu có buổi học,
/// viền cam nếu là hôm nay, nền navy nếu đang chọn.
class _DayBar extends StatelessWidget {
  const _DayBar({required this.vm, required this.today});

  final TimetableViewModel vm;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, (day, _)) in vm.days.indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => vm.selectDay(i + 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: day == vm.selectedDay ? fapNavy : null,
                    borderRadius: BorderRadius.circular(10),
                    border: day == today
                        ? Border.all(color: fptOrange, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _weekdays[i],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: day == vm.selectedDay
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: day == vm.selectedDay
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      // Chấm báo ngày có buổi học.
                      SizedBox(
                        width: 5,
                        height: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: vm.hasSessionsOn(day) ? fptOrange : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.vm, required this.today});

  final TimetableViewModel vm;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final day = vm.selectedDay;
    final sessions = vm.sessionsOfSelectedDay;
    final text = Theme.of(context).textTheme;
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Thứ ${day.weekday + 1 == 8 ? 'CN' : day.weekday + 1}, '
              '${_two(day.day)}/${_two(day.month)}'
              '${day == today ? ' · Hôm nay' : ''}',
              style: text.titleSmall,
            ),
          ),
          if (sessions.isEmpty) _EmptyDay(),
          for (final s in sessions)
            _SessionCard(
              session: s,
              user: vm.user,
              isToday: day == today,
              onChanged: vm.load,
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.free_breakfast_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Không có lịch',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.user,
    required this.isToday,
    required this.onChanged,
  });

  final ClassSession session;
  final AppUser user;
  final bool isToday;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final isStudent = user.role == UserRole.student;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Sinh viên: màu theo trạng thái điểm danh; giảng viên: cam nếu chưa điểm.
    final stripe = isStudent
        ? switch (session.statusOf(user.uid)) {
            AttendanceStatus.present => scheme.primary,
            AttendanceStatus.absent => scheme.error,
            AttendanceStatus.notYet => scheme.outlineVariant,
          }
        : (session.taken ? scheme.primary : scheme.outlineVariant);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
        // Dải màu bên trái cao đúng bằng thẻ: Row nằm trong ListView (chiều
        // cao vô hạn) nên phải bọc IntrinsicHeight mới stretch được.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: stripe),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${session.slot}',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('Slot', style: text.labelSmall),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.subjectCode} - ${session.classCode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.slotTime} · Phòng ${session.room}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Buổi ${session.sessionNo} · '
                        'GV: ${session.lecturerName ?? 'chưa phân công'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: isStudent
                    ? StatusChip.attendance(session.statusOf(user.uid))
                    : Icon(
                        session.taken
                            ? Icons.check_circle
                            : Icons.chevron_right,
                        color: session.taken ? scheme.primary : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
