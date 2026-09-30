import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        title: Text('Phân công GV (${vm.unassignedCount} lớp chưa có)'),
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: AsyncBody(
          vm: vm,
          isEmpty: vm.classes.isEmpty,
          emptyText: 'Bộ môn chưa có lớp nào',
          onRetry: vm.load,
          builder: (context) => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.classes.length,
            itemBuilder: (context, i) {
              final c = vm.classes[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${c.title} · ${c.subjectName}'),
                  subtitle: Text(
                    c.lecturerName == null
                        ? 'Chưa phân công'
                        : 'Giảng viên: ${c.lecturerName}',
                  ),
                  trailing: TextButton(
                    onPressed: vm.busy ? null : () => _pick(context, vm, c),
                    child: Text(c.lecturerId == null ? 'Phân công' : 'Đổi GV'),
                  ),
                ),
              );
            },
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
                title: Text(l.fullName),
                subtitle: Text(l.code),
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
