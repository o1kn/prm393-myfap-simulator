import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../data/models/app_user.dart';
import '../data/models/course_class.dart';
import '../data/repositories/academic_repository.dart';
import '../data/repositories/grade_repository.dart';
import '../data/repositories/user_repository.dart';
import '../viewmodels/grade_sheet_view_model.dart';
import 'widgets/common.dart';

/// Bảng điểm lớp. Giảng viên nhập và gửi duyệt; trưởng bộ môn xem rồi công
/// bố hoặc trả lại.
class GradeSheetScreen extends StatelessWidget {
  const GradeSheetScreen({
    super.key,
    required this.course,
    required this.viewer,
  });

  final CourseClass course;
  final AppUser viewer;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GradeSheetViewModel(
        context.read<AcademicRepository>(),
        context.read<GradeRepository>(),
        context.read<UserRepository>(),
        course,
        viewer,
      )..load(),
      child: _GradeSheetView(isHead: viewer.role == UserRole.head),
    );
  }
}

class _GradeSheetView extends StatelessWidget {
  const _GradeSheetView({required this.isHead});

  final bool isHead;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GradeSheetViewModel>();
    final course = vm.course;
    final canEdit = !isHead && vm.editable;
    // Chặn back hệ thống / thanh tiêu đề khi còn thay đổi chưa lưu: Lưu /
    // Bỏ thay đổi / Ở lại. Lưu thất bại thì ở lại, vết bẩn còn nguyên.
    return PopScope(
      canPop: !vm.hasUnsavedChanges && !vm.busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final action = await _confirmUnsavedGrades(context, vm);
        if (!context.mounted) return;
        switch (action) {
          case _GradeBackAction.save:
            final ok = await vm.saveDraft();
            if (!context.mounted) return;
            showResult(context, vm, 'Đã lưu nháp');
            if (ok) Navigator.of(context).pop();
          case _GradeBackAction.discard:
            Navigator.of(context).pop();
          case _GradeBackAction.stay:
          case null:
            break;
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          'Bảng điểm ${course.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: AsyncBody(
        vm: vm,
        isEmpty: vm.subject == null,
        emptyText: 'Không tải được môn học',
        onRetry: vm.load,
        builder: (context) => ContentWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _SummaryHero(vm: vm),
              // Trạng thái lưu hiện diện suốt màn hình: đã lưu / chưa lưu.
              _SaveStateBanner(hasUnsaved: vm.hasUnsavedChanges),
              if (course.headNote.isNotEmpty)
                _HeadNote(
                  note: course.headNote,
                  returned: course.gradeStatus == GradeStatus.returned,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel('Sinh viên'),
                    for (final st in vm.students)
                      _StudentTile(vm: vm, student: st, canEdit: canEdit),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: vm.subject == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isHead
                      ? _HeadActions(vm: vm)
                      : _LecturerActions(vm: vm, enabled: canEdit),
                ),
              ),
            ),
      ),
    );
  }
}
/// Lựa chọn khi back lúc còn thay đổi chưa lưu.
enum _GradeBackAction { save, discard, stay }

/// Hỏi Lưu / Bỏ thay đổi / Ở lại. Ô nhập sai thì nhắc sửa trước khi lưu.
Future<_GradeBackAction?> _confirmUnsavedGrades(
  BuildContext context,
  GradeSheetViewModel vm,
) => showDialog<_GradeBackAction>(
  context: context,
  builder: (dialog) => AlertDialog(
    title: const Text('Còn thay đổi chưa lưu'),
    content: Text(
      vm.invalidCells.isNotEmpty
          ? 'Còn ô điểm không hợp lệ — sửa rồi hãy lưu, hoặc bỏ thay đổi.'
          : 'Lưu nháp các điểm đã nhập trước khi thoát?',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialog, _GradeBackAction.stay),
        child: const Text('Ở lại'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(dialog, _GradeBackAction.discard),
        child: const Text('Bỏ thay đổi'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialog, _GradeBackAction.save),
        child: const Text('Lưu'),
      ),
    ],
  ),
);

/// Dòng trạng thái lưu luôn hiện: đã lưu (xanh) / chưa lưu (cam).
class _SaveStateBanner extends StatelessWidget {
  const _SaveStateBanner({required this.hasUnsaved});

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


/// Khung navy: tên môn, trạng thái bảng điểm, số sinh viên đã đủ điểm.
class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.vm});

  final GradeSheetViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = vm.students.length;
    final done = vm.completeCount;
    final components = vm.subject!.components
        .map((c) => '${c.name} ${c.weight.toStringAsFixed(0)}%')
        .join(', ');
    return HeroHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vm.course.subjectName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          StatusChip.grade(vm.course.gradeStatus),
          const SizedBox(height: 4),
          Text(
            'Đầu điểm: $components',
            style: text.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Text(
            'Đã đủ điểm',
            style: text.titleSmall?.copyWith(color: Colors.white),
          ),
          Text(
            '$done/$total',
            style: text.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              color: fptOrange,
              backgroundColor: Colors.white24,
              semanticsLabel: 'Đã đủ điểm $done/$total',
            ),
          ),
        ],
      ),
    );
  }
}

/// Lý do trưởng bộ môn trả lại bảng điểm (giữ nguyên nội dung cũ).
class _HeadNote extends StatelessWidget {
  const _HeadNote({required this.note, required this.returned});

  final String note;
  final bool returned;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (fg, bg) = StatusColors.of(
      context,
    ).forTone(returned ? Tone.bad : Tone.pending);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(appRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.chat_bubble_outline, color: fg, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trưởng BM',
                    style: text.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(note, style: text.bodyMedium?.copyWith(color: fg)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một sinh viên: hàng gọn (tên, mã, số đầu điểm, điểm TB) bấm để mở ô nhập.
/// `maintainState` giữ chữ đã gõ khi hàng được thu lại.
class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.vm,
    required this.student,
    required this.canEdit,
  });

  final GradeSheetViewModel vm;
  final AppUser student;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final st = student;
    final components = vm.subject!.components;
    final marks = vm.marksOf(st.uid);
    final filled = components.where(
      (c) => marks.containsKey(c.name) &&
          !vm.invalidCells.contains('${st.uid}|${c.name}'),
    ).length;
    final invalid = vm.invalidCells.any((k) => k.startsWith('${st.uid}|'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        // Có ô nhập sai: viền đỏ dù hàng đang thu lại.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appRadius),
          side: BorderSide(
            color: invalid ? scheme.error : scheme.outlineVariant,
            width: invalid ? 2 : 1,
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey('tile-${st.uid}'),
            maintainState: true,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            leading: CircleAvatar(
              backgroundColor: invalid
                  ? scheme.errorContainer
                  : scheme.primaryContainer,
              foregroundColor: invalid
                  ? scheme.onErrorContainer
                  : scheme.onPrimaryContainer,
              child: Text(
                _initial(st.fullName),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(
              st.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  st.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('$filled/${components.length} đầu điểm'),
                    _AverageBadge(invalid ? null : vm.averageOf(st.uid)),
                  ],
                ),
                if (invalid)
                  Text(
                    'Có ô điểm không hợp lệ',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            children: [
              // 2 ô điểm mỗi hàng; màn hẹp thì mỗi ô một hàng cho khỏi bị cắt.
              LayoutBuilder(
                builder: (context, box) {
                  final fieldWidth =
                      box.maxWidth < MediaQuery.textScalerOf(context).scale(300)
                      ? box.maxWidth
                      : (box.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in components)
                        SizedBox(
                          width: fieldWidth,
                          child: _MarkField(
                            key: ValueKey('${st.uid}-${c.name}'),
                            label: c.name,
                            initial: marks[c.name],
                            enabled: canEdit,
                            onChanged: (v) => vm.setMark(st.uid, c.name, v),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Trung bình: '
                '${vm.averageOf(st.uid)?.toStringAsFixed(1) ?? '-'}',
                style: text.titleSmall,
              ),
              _AttendanceLine(vm: vm, studentId: st.uid),
            ],
          ),
        ),
      ),
    );
  }
}

/// Điểm danh của một sinh viên trong lớp: vắng X/Y buổi. Chỉ tính buổi mà
/// sinh viên còn trong danh sách (qua `summaryOf`) nên khớp Attendance
/// report; vắng quá 20% thì cảnh báo cấm thi như Grade report.
class _AttendanceLine extends StatelessWidget {
  const _AttendanceLine({required this.vm, required this.studentId});

  final GradeSheetViewModel vm;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final summary = vm.summaryOf(studentId);
    final scheme = Theme.of(context).colorScheme;
    if (summary.total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Điểm danh: vắng ${summary.absent}/${summary.total} buổi'
        '${summary.isBanned ? ' · Vắng quá 20%: không đủ điều kiện dự thi' : ''}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: summary.isBanned ? scheme.error : scheme.onSurfaceVariant,
          fontWeight: summary.isBanned ? FontWeight.w700 : null,
        ),
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

/// Điểm trung bình dạng nhãn: >= 5 xanh, < 5 đỏ, chưa có thì xám.
class _AverageBadge extends StatelessWidget {
  const _AverageBadge(this.average);

  final double? average;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg) = switch (average) {
      null => (scheme.onSurfaceVariant, scheme.surfaceContainerHigh),
      final a => StatusColors.of(
        context,
      ).forTone(a >= 5 ? Tone.good : Tone.bad),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tagRadius),
      ),
      child: Text(
        average?.toStringAsFixed(1) ?? '-',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MarkField extends StatefulWidget {
  const _MarkField({
    super.key,
    required this.label,
    required this.initial,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double? initial;
  final bool enabled;
  final String? Function(String) onChanged;

  @override
  State<_MarkField> createState() => _MarkFieldState();
}

class _MarkFieldState extends State<_MarkField> {
  late final _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: _error,
        errorMaxLines: 3,
        constraints: const BoxConstraints(minHeight: 48),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onChanged: (v) => setState(() => _error = widget.onChanged(v)),
    );
  }
}

class _LecturerActions extends StatelessWidget {
  const _LecturerActions({required this.vm, required this.enabled});

  final GradeSheetViewModel vm;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Text(
        'Bảng điểm ${vm.course.gradeStatus.label.toLowerCase()}: không sửa được.',
        textAlign: TextAlign.center,
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: vm.busy
              ? null
              : () async {
                  await vm.saveDraft();
                  if (context.mounted) showResult(context, vm, 'Đã lưu nháp');
                },
          child: const Text('Lưu nháp'),
        ),
        FilledButton(
          onPressed: vm.busy
              ? null
              : () async {
                  final ok = await _confirmSubmit(context, vm);
                  if (!ok) return;
                  await vm.submit();
                  if (context.mounted) {
                    showResult(context, vm, 'Đã gửi trưởng bộ môn duyệt');
                  }
                },
          child: const Text('Gửi duyệt'),
        ),
      ],
    );
  }

  /// Xác nhận gửi duyệt: nêu rõ lớp và hậu quả (không sửa được sau khi gửi).
  Future<bool> _confirmSubmit(
    BuildContext context,
    GradeSheetViewModel vm,
  ) async {
    final missing = vm.students.length - vm.completeCount;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Gửi duyệt bảng điểm?'),
            content: Text(
              'Lớp ${vm.course.title} · ${vm.course.subjectName} '
              '(${vm.students.length} sinh viên).\n'
              '${missing > 0 ? 'Còn $missing sinh viên chưa đủ đầu điểm (sẽ bị từ chối). ' : ''}'
              'Sau khi gửi, giảng viên không thể sửa; '
              'trưởng bộ môn sẽ công bố hoặc trả lại.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Gửi duyệt'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _HeadActions extends StatelessWidget {
  const _HeadActions({required this.vm});

  final GradeSheetViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.course.gradeStatus != GradeStatus.submitted) {
      return Text(
        'Chỉ duyệt được bảng điểm đang chờ duyệt '
        '(hiện: ${vm.course.gradeStatus.label}).',
        textAlign: TextAlign.center,
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: vm.busy ? null : () => _returnSheet(context),
          child: const Text('Trả lại'),
        ),
        FilledButton(
          onPressed: vm.busy
              ? null
              : () async {
                  final ok = await _confirmPublish(context, vm);
                  if (!ok) return;
                  await vm.publish();
                  if (context.mounted) {
                    showResult(context, vm, 'Đã công bố điểm cho sinh viên');
                  }
                },
          child: const Text('Công bố'),
        ),
      ],
    );
  }

  /// Xác nhận công bố: nêu rõ lớp, sĩ số và hậu quả không thể hoàn tác.
  Future<bool> _confirmPublish(
    BuildContext context,
    GradeSheetViewModel vm,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Công bố bảng điểm?'),
            content: Text(
              'Lớp ${vm.course.title} · ${vm.course.subjectName} '
              '(${vm.students.length} sinh viên).\n'
              'Sinh viên sẽ thấy điểm ngay; '
              'thao tác này không thể hoàn tác.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Công bố'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _returnSheet(BuildContext context) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Trả lại bảng điểm'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Lý do'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Trả lại'),
          ),
        ],
      ),
    );
    if (ok == true) await vm.returnToLecturer(note.text);
    note.dispose();
    if (ok == true && context.mounted) {
      showResult(context, vm, 'Đã trả lại cho giảng viên');
    }
  }
}
