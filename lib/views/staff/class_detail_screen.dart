import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/constants.dart';
import '../../data/models/class_session.dart';
import '../../data/models/course_class.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../viewmodels/staff/class_detail_view_model.dart';
import '../widgets/common.dart';

final _day = DateFormat('dd/MM/yyyy');

/// Chi tiết lớp cho cán bộ đào tạo: roster + lịch học (chỉ đọc) và thêm
/// sinh viên đã có tài khoản vào buổi sắp tới chưa điểm danh.
class ClassDetailScreen extends StatelessWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ClassDetailViewModel(
        context.read<AcademicRepository>(),
        context.read<UserRepository>(),
        classId,
      )..load(),
      child: const _ClassDetailView(),
    );
  }
}

class _ClassDetailView extends StatelessWidget {
  const _ClassDetailView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClassDetailViewModel>();
    final course = vm.course;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          course == null ? 'Chi tiết lớp' : course.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: AsyncBody(
        vm: vm,
        isEmpty: course == null,
        emptyText: 'Không tải được lớp',
        onRetry: vm.load,
        builder: (context) => ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: const [
              _InfoSection(),
              _ScheduleSection(),
              _RosterSection(),
              _EnrollSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClassDetailViewModel>();
    final course = vm.course!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Thông tin lớp'),
        InfoRow('Môn học', course.subjectName),
        InfoRow('Học kỳ', course.semester),
        InfoRow('Bộ môn', course.department),
        InfoRow(
          'Giảng viên',
          course.lecturerName ?? 'chưa phân công',
        ),
        const SizedBox(height: 8),
        StatusChip.grade(course.gradeStatus),
        const SizedBox(height: 12),
        StatTile(
          value: '${vm.enrolledCount}',
          label: 'Sinh viên đã ghi danh',
        ),
      ],
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClassDetailViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Lịch học (${vm.sessions.length} buổi)'),
        for (final s in vm.sessions) _SessionTile(s),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile(this.session);

  final ClassSession session;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          'Buổi ${session.sessionNo} · ${_day.format(session.date)}',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Slot ${session.slot} · ${slotTimes[session.slot] ?? ''} · '
          '${session.room}',
        ),
        trailing: session.taken
            ? const StatusChip('Đã điểm danh', Tone.good)
            : StatusChip.attendance(AttendanceStatus.notYet),
      ),
    );
  }
}

class _RosterSection extends StatelessWidget {
  const _RosterSection();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClassDetailViewModel>();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Danh sách sinh viên (${vm.enrolledCount})'),
        if (vm.missingProfiles > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Có ${vm.missingProfiles} mã sinh viên chưa có hồ sơ.',
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        for (final u in vm.roster)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                u.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall,
              ),
              subtitle: Text(u.code),
            ),
          ),
      ],
    );
  }
}

class _EnrollSection extends StatelessWidget {
  const _EnrollSection();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClassDetailViewModel>();
    final editable =
        vm.course!.gradeStatus.lecturerCanEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Ghi danh bổ sung'),
        Text(
          'Sinh viên mới chỉ được ghi danh vào buổi sắp tới chưa điểm danh; '
          'buổi đã qua hoặc đã điểm danh giữ nguyên, không bịa điểm danh.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Thêm sinh viên'),
          onPressed: !editable || vm.busy
              ? null
              : () => _pickStudent(context, vm),
        ),
        if (!editable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              vm.course?.gradeStatus == GradeStatus.published
                  ? 'Lớp đã công bố, không thể thêm sinh viên.'
                  : 'Lớp đã gửi duyệt, không thể thêm sinh viên.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickStudent(
    BuildContext context,
    ClassDetailViewModel vm,
  ) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn sinh viên'),
        content: SizedBox(
          width: double.maxFinite,
          child: vm.candidates.isEmpty
              ? const Text('Không còn sinh viên để thêm.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: vm.candidates.length,
                  itemBuilder: (context, i) {
                    final u = vm.candidates[i];
                    final n = vm.eligibleCountFor(u.uid);
                    return ListTile(
                      title: Text(
                        u.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${u.code} · ghi danh vào $n buổi sắp tới',
                      ),
                      onTap: () => Navigator.of(context).pop(u.uid),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    var code = picked;
    for (final u in vm.candidates) {
      if (u.uid == picked) {
        code = u.code;
        break;
      }
    }
    await vm.enroll(picked);
    if (!context.mounted) return;
    showResult(
      context,
      vm,
      vm.lastAddedSessions > 0
          ? 'Đã thêm $code vào ${vm.lastAddedSessions} buổi sắp tới, '
              'không sửa buổi đã qua'
          : 'Đã thêm $code vào lớp, không còn buổi sắp tới để ghi danh',
    );
  }
}
