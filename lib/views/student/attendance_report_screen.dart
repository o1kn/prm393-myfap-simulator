import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/academic_repository.dart';
import '../../viewmodels/student/attendance_report_view_model.dart';
import '../widgets/common.dart';

/// Attendance report: chọn lớp môn, xem từng buổi và tỉ lệ vắng.
class AttendanceReportScreen extends StatelessWidget {
  const AttendanceReportScreen({super.key, required this.student});

  final AppUser student;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          AttendanceReportViewModel(context.read<AcademicRepository>(), student)
            ..load(),
      child: const _AttendanceView(),
    );
  }
}

class _AttendanceView extends StatelessWidget {
  const _AttendanceView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AttendanceReportViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Điểm danh')),
      body: AsyncBody(
        vm: vm,
        isEmpty: vm.classes.isEmpty,
        emptyText: 'Bạn chưa có lớp môn nào trong kỳ',
        onRetry: vm.load,
        builder: (context) {
          final summary = vm.summary;
          final banned = summary.isBanned;
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: vm.selectedClassId,
                decoration: const InputDecoration(labelText: 'Lớp môn'),
                items: [
                  for (final c in vm.classes)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.title} · ${c.subjectName}'),
                    ),
                ],
                onChanged: (id) => vm.select(id!),
              ),
              const SizedBox(height: 12),
              Card(
                color: banned ? scheme.errorContainer : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Vắng ${(summary.absentRate * 100).round()}% '
                    '(${summary.absent}/${summary.total} buổi), '
                    '${summary.notYet} buổi chưa diễn ra.'
                    '${banned ? '\nVượt 20%: không đủ điều kiện dự thi.' : ''}',
                    style: TextStyle(
                      color: banned ? scheme.onErrorContainer : null,
                      fontWeight: banned ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final s in vm.sessions)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${s.sessionNo}')),
                    title: Text(
                      '${s.dateKey} · Slot ${s.slot} (${s.slotTime})',
                    ),
                    subtitle: Text(
                      'Phòng ${s.room} · GV ${s.lecturerName ?? '-'}',
                    ),
                    trailing: StatusChip.attendance(s.statusOf(vm.student.uid)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
