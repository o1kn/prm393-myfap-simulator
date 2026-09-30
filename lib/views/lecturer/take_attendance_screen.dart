import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/class_session.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../viewmodels/lecturer/take_attendance_view_model.dart';
import '../widgets/common.dart';

class TakeAttendanceScreen extends StatelessWidget {
  const TakeAttendanceScreen({super.key, required this.session});

  final ClassSession session;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TakeAttendanceViewModel(
        context.read<AcademicRepository>(),
        context.read<UserRepository>(),
        session,
      )..load(),
      child: const _TakeAttendanceView(),
    );
  }
}

class _TakeAttendanceView extends StatelessWidget {
  const _TakeAttendanceView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TakeAttendanceViewModel>();
    final s = vm.session;
    return Scaffold(
      appBar: AppBar(
        title: Text('Điểm danh ${s.subjectCode} - ${s.classCode}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    InfoRow('Buổi', '${s.sessionNo} · ${s.dateKey}'),
                    InfoRow('Slot', '${s.slot} (${s.slotTime})'),
                    InfoRow('Phòng', s.room),
                    InfoRow(
                      'Vắng',
                      '${vm.absentCount}/${vm.students.length} sinh viên',
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!vm.editable)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Buổi học chưa diễn ra: chỉ xem, chưa điểm danh được.',
              ),
            ),
          Expanded(
            child: AsyncBody(
              vm: vm,
              isEmpty: vm.students.isEmpty,
              emptyText: 'Lớp chưa có sinh viên',
              onRetry: vm.load,
              builder: (_) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: vm.students.length,
                itemBuilder: (context, i) {
                  final st = vm.students[i];
                  final absent = vm.marks[st.uid] == AttendanceStatus.absent;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SwitchListTile(
                      value: !absent,
                      onChanged: vm.editable ? (_) => vm.toggle(st.uid) : null,
                      title: Text(st.fullName),
                      subtitle: Text(st.code),
                      secondary: StatusChip.attendance(
                        absent
                            ? AttendanceStatus.absent
                            : AttendanceStatus.present,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: vm.editable && vm.students.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.save_outlined),
              label: Text(s.taken ? 'Cập nhật điểm danh' : 'Lưu điểm danh'),
              onPressed: vm.busy
                  ? null
                  : () async {
                      final ok = await vm.save();
                      if (!context.mounted) return;
                      showResult(context, vm, 'Đã lưu điểm danh');
                      if (ok) Navigator.of(context).pop();
                    },
            )
          : null,
    );
  }
}
