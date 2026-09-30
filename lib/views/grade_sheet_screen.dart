import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text('Bảng điểm ${course.title}')),
      body: AsyncBody(
        vm: vm,
        isEmpty: vm.subject == null,
        emptyText: 'Không tải được môn học',
        onRetry: vm.load,
        builder: (context) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.subjectName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        StatusChip.grade(course.gradeStatus),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InfoRow(
                      'Đầu điểm',
                      vm.subject!.components
                          .map(
                            (c) => '${c.name} ${c.weight.toStringAsFixed(0)}%',
                          )
                          .join(', '),
                    ),
                    InfoRow(
                      'Đã đủ điểm',
                      '${vm.completeCount}/${vm.students.length} sinh viên',
                    ),
                    if (course.headNote.isNotEmpty)
                      InfoRow('Trưởng BM', course.headNote),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final st in vm.students)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${st.fullName} · ${st.code}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      // 2 ô điểm mỗi hàng để tên đầu điểm hiện đủ.
                      LayoutBuilder(
                        builder: (context, box) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in vm.subject!.components)
                              SizedBox(
                                width: (box.maxWidth - 8) / 2,
                                child: _MarkField(
                                  key: ValueKey('${st.uid}-${c.name}'),
                                  label: c.name,
                                  initial: vm.marks[st.uid]![c.name],
                                  enabled: canEdit,
                                  onChanged: (v) =>
                                      vm.setMark(st.uid, c.name, v),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Trung bình: '
                        '${vm.averageOf(st.uid)?.toStringAsFixed(1) ?? '-'}',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: vm.subject == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isHead
                    ? _HeadActions(vm: vm)
                    : _LecturerActions(vm: vm, enabled: canEdit),
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
        isDense: true,
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
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: vm.busy
                ? null
                : () async {
                    await vm.saveDraft();
                    if (context.mounted) showResult(context, vm, 'Đã lưu nháp');
                  },
            child: const Text('Lưu nháp'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: vm.busy
                ? null
                : () async {
                    await vm.submit();
                    if (context.mounted) {
                      showResult(context, vm, 'Đã gửi trưởng bộ môn duyệt');
                    }
                  },
            child: const Text('Gửi duyệt'),
          ),
        ),
      ],
    );
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
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: vm.busy ? null : () => _returnSheet(context),
            child: const Text('Trả lại'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: vm.busy
                ? null
                : () async {
                    await vm.publish();
                    if (context.mounted) {
                      showResult(context, vm, 'Đã công bố điểm cho sinh viên');
                    }
                  },
            child: const Text('Công bố'),
          ),
        ),
      ],
    );
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
