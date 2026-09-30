import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../data/models/app_user.dart';
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
    // Chặn back khi còn thay đổi chưa lưu: Lưu / Bỏ thay đổi / Ở lại.
    // Lưu thất bại thì ở lại, vết bẩn còn nguyên.
    return PopScope(
      canPop: !vm.hasUnsavedChanges && !vm.busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final action = await _confirmUnsavedAttendance(context);
        if (!context.mounted) return;
        switch (action) {
          case _AttendanceBackAction.save:
            final ok = await vm.save();
            if (!context.mounted) return;
            showResult(context, vm, 'Đã lưu điểm danh');
            if (ok) Navigator.of(context).pop();
          case _AttendanceBackAction.discard:
            Navigator.of(context).pop();
          case _AttendanceBackAction.stay:
          case null:
            break;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Điểm danh ${s.subjectCode} - ${s.classCode}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      body: AsyncBody(
        vm: vm,
        isEmpty: vm.students.isEmpty,
        emptyText: 'Lớp chưa có sinh viên',
        onRetry: vm.load,
        builder: (_) => ContentWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _SessionHero(vm: vm),
              // Trạng thái lưu hiện diện suốt màn hình.
              _AttendanceSaveBanner(hasUnsaved: vm.hasUnsavedChanges),
              // Chỉ xem: phân biệt lớp đã công bố / buổi chưa diễn ra.
              if (vm.readonlyReason case final reason?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        vm.isPublished
                            ? Icons.lock_outlined
                            : Icons.lock_clock_outlined,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(reason)),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel('Sinh viên'),
                    for (final st in vm.students)
                      _StudentRow(vm: vm, student: st),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: vm.editable && vm.students.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.save_outlined),
              tooltip: s.taken ? 'Cập nhật điểm danh' : 'Lưu điểm danh',
              label: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 120,
                ),
                child: Text(
                  s.taken ? 'Cập nhật điểm danh' : 'Lưu điểm danh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
      ),
    );
  }
}

/// Lựa chọn khi back lúc điểm danh còn thay đổi chưa lưu.
enum _AttendanceBackAction { save, discard, stay }

/// Hỏi Lưu / Bỏ thay đổi / Ở lại cho màn điểm danh.
Future<_AttendanceBackAction?> _confirmUnsavedAttendance(
  BuildContext context,
) => showDialog<_AttendanceBackAction>(
  context: context,
  builder: (dialog) => AlertDialog(
    title: const Text('Còn thay đổi chưa lưu'),
    content: const Text('Lưu điểm danh đã chọn trước khi thoát?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialog, _AttendanceBackAction.stay),
        child: const Text('Ở lại'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(dialog, _AttendanceBackAction.discard),
        child: const Text('Bỏ thay đổi'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialog, _AttendanceBackAction.save),
        child: const Text('Lưu'),
      ),
    ],
  ),
);

/// Dòng trạng thái lưu luôn hiện: đã lưu / chưa lưu thay đổi.
class _AttendanceSaveBanner extends StatelessWidget {
  const _AttendanceSaveBanner({required this.hasUnsaved});

  final bool hasUnsaved;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = StatusColors.of(context).forTone(
      hasUnsaved ? Tone.pending : Tone.good,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(appRadius),
        ),
        child: Row(
          children: [
            Icon(
              hasUnsaved ? Icons.edit_outlined : Icons.check_circle_outline,
              color: fg,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              hasUnsaved ? 'Chưa lưu thay đổi' : 'Đã lưu',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung navy: thông tin buổi học, và (khi điểm danh được) số có mặt / vắng.
class _SessionHero extends StatelessWidget {
  const _SessionHero({required this.vm});

  final TakeAttendanceViewModel vm;

  @override
  Widget build(BuildContext context) {
    final s = vm.session;
    final text = Theme.of(context).textTheme;
    final present = vm.marks.values
        .where((m) => m == AttendanceStatus.present)
        .length;
    return HeroHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buổi ${s.sessionNo} · ${s.dateKey}',
            style: text.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Slot ${s.slot} (${s.slotTime}) · Phòng ${s.room}',
            style: text.bodyMedium?.copyWith(color: Colors.white70),
          ),
          if (vm.editable) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatTile(value: '$present', label: 'Có mặt'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    value: '${vm.absentCount}',
                    label: 'Vắng',
                    highlight: vm.absentCount > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Vắng: ',
                  style: text.bodyMedium?.copyWith(color: Colors.white70),
                ),
                Expanded(
                  child: Text(
                    '${vm.absentCount}/${vm.students.length} sinh viên',
                    style: text.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Một sinh viên: chữ cái đầu, tên, mã, nhãn trạng thái; cả hàng là công tắc.
class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.vm, required this.student});

  final TakeAttendanceViewModel vm;
  final AppUser student;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = vm.marks[student.uid]!;
    final absent = status == AttendanceStatus.absent;
    final avatar = CircleAvatar(
      backgroundColor: absent
          ? scheme.errorContainer
          : scheme.primaryContainer,
      foregroundColor: absent
          ? scheme.onErrorContainer
          : scheme.onPrimaryContainer,
      child: Text(
        _initial(student.fullName),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
    final title = Text(
      student.fullName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(student.code, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        StatusChip.attendance(status),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: absent ? StatusColors.of(context).rejectedBg : null,
        child: vm.editable
            ? SwitchListTile(
                value: !absent,
                onChanged: (_) => vm.toggle(student.uid),
                secondary: avatar,
                title: title,
                subtitle: details,
              )
            : ListTile(leading: avatar, title: title, subtitle: details),
      ),
    );
  }
}

/// Chữ cái đầu của tên riêng (từ cuối trong họ tên tiếng Việt).
String _initial(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  final last = parts.last;
  return last.isEmpty ? '?' : last.substring(0, 1).toUpperCase();
}
