import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/app_user.dart';
import '../data/models/course_class.dart';
import '../data/repositories/academic_repository.dart';
import '../viewmodels/class_list_view_model.dart';
import 'grade_sheet_screen.dart';
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
          builder: (context) => ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: vm.classes.length,
            itemBuilder: (context, i) => _ClassCard(vm.classes[i], vm),
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
    final opensSheet = vm.user.role != UserRole.staff;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: opensSheet
            ? () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GradeSheetScreen(course: course, viewer: vm.user),
                  ),
                );
                await vm.load();
              }
            : null,
        title: Text('${course.title} · ${course.subjectName}'),
        subtitle: Text(
          '${course.semester} · ${course.studentIds.length} SV · '
          'GV ${course.lecturerName ?? 'chưa phân công'}',
        ),
        trailing: StatusChip.grade(course.gradeStatus),
      ),
    );
  }
}
