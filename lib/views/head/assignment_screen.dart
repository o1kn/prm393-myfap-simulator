import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/course_class.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../viewmodels/head/assignment_view_model.dart';
import '../widgets/common.dart';

/// Trưởng bộ môn phân công giảng viên cho lớp môn thuộc bộ môn.
class AssignmentScreen extends StatelessWidget {
  const AssignmentScreen({super.key, required this.head});

  final AppUser head;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AssignmentViewModel(
        context.read<AcademicRepository>(),
        context.read<UserRepository>(),
        head,
      )..load(),
      child: const _AssignmentView(),
    );
  }
}

class _AssignmentView extends StatelessWidget {
  const _AssignmentView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssignmentViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Phân công GV (${vm.unassignedCount} lớp chưa có)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: AsyncBody(
          vm: vm,
          isEmpty: vm.classes.isEmpty,
          emptyText: 'Bộ môn chưa có lớp nào',
          onRetry: vm.load,
          builder: (context) => ContentWidth(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vm.classes.length,
              itemBuilder: (context, i) {
                final c = vm.classes[i];
                final assigned = c.lecturerId != null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.title} · ${c.subjectName}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(
                              assigned
                                  ? 'Giảng viên: ${c.lecturerName ?? c.lecturerId}'
                                  : 'Chưa phân công',
                              assigned ? Tone.good : Tone.pending,
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.person_add_alt_outlined),
                              onPressed: vm.busy
                                  ? null
                                  : () => _pick(context, vm, c),
                              label: Text(assigned ? 'Đổi GV' : 'Phân công'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    AssignmentViewModel vm,
    CourseClass course,
  ) async {
    final lecturer = await showModalBottomSheet<AppUser>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                'Chọn giảng viên cho ${course.title}',
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            for (final l in vm.lecturers)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(
                  l.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  l.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: l.uid == course.lecturerId,
                onTap: () => Navigator.pop(sheet, l),
              ),
          ],
        ),
      ),
    );
    if (lecturer == null) return;
    await vm.assign(course, lecturer);
    if (context.mounted) {
      showResult(context, vm, 'Đã phân công ${lecturer.fullName}');
    }
  }
}
