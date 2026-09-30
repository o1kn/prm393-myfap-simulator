import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../data/models/app_user.dart';
import '../data/models/course_class.dart';
import '../data/repositories/academic_repository.dart';
import '../viewmodels/class_list_view_model.dart';
import 'grade_sheet_screen.dart';
import 'staff/class_detail_screen.dart';
import 'staff/create_class_screen.dart';
import 'widgets/common.dart';

/// Danh sách lớp môn:
/// - Giảng viên: lớp mình dạy → nhập điểm.
/// - Trưởng bộ môn: lớp thuộc bộ môn → duyệt bảng điểm.
/// - Cán bộ đào tạo: mọi lớp + mở lớp mới.
class ClassListScreen extends StatelessWidget {
  const ClassListScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ClassListViewModel(context.read<AcademicRepository>(), user)..load(),
      child: const _ClassListView(),
    );
  }
}

class _ClassListView extends StatelessWidget {
  const _ClassListView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClassListViewModel>();
    final role = vm.user.role;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (role) {
          UserRole.lecturer => 'Nhập điểm',
          UserRole.head => 'Duyệt bảng điểm',
          _ => 'Lớp môn & lịch học',
        }),
      ),
      floatingActionButton: role == UserRole.staff
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Mở lớp'),
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CreateClassScreen()),
                );
                if (created == true) await vm.load();
              },
            )
          : null,
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: AsyncBody(
          vm: vm,
          isEmpty: vm.classes.isEmpty,
          emptyText: role == UserRole.lecturer
              ? 'Bạn chưa được phân công lớp nào'
              : 'Chưa có lớp môn',
          onRetry: vm.load,
          builder: (context) => ContentWidth(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: vm.classes.length,
              itemBuilder: (context, i) => _ClassCard(vm.classes[i], vm),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard(this.course, this.vm);

  final CourseClass course;
  final ClassListViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tone = switch (course.gradeStatus) {
      GradeStatus.published => Tone.good,
      GradeStatus.returned => Tone.bad,
      _ => Tone.pending,
    };
    final (stripe, _) = StatusColors.of(context).forTone(tone);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          if (vm.user.role == UserRole.staff) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ClassDetailScreen(classId: course.id),
              ),
            );
            await vm.load();
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GradeSheetScreen(course: course, viewer: vm.user),
            ),
          );
          await vm.load();
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: stripe, width: 4)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${course.title} · ${course.subjectName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(course.semester),
                  _MetaChip('${course.studentIds.length} SV'),
                  _MetaChip('GV ${course.lecturerName ?? 'chưa phân công'}'),
                ],
              ),
              const SizedBox(height: 12),
              StatusChip.grade(course.gradeStatus),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tagRadius),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
