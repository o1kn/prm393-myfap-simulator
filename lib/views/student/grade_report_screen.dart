import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/grade_repository.dart';
import '../../viewmodels/student/results_view_model.dart';
import '../widgets/common.dart';

/// Grade report: điểm thành phần của một lớp môn (chỉ khi đã công bố).
class GradeReportScreen extends StatelessWidget {
  const GradeReportScreen({super.key, required this.student});

  final AppUser student;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ResultsViewModel(
        context.read<AcademicRepository>(),
        context.read<GradeRepository>(),
        student,
      )..load(),
      child: const _GradeReportView(),
    );
  }
}

class _GradeReportView extends StatelessWidget {
  const _GradeReportView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResultsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Điểm học kỳ')),
      body: AsyncBody(
        vm: vm,
        isEmpty: vm.rows.isEmpty,
        emptyText: 'Bạn chưa có lớp môn nào',
        onRetry: vm.load,
        builder: (context) {
          final row = vm.selected!;
          final text = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: vm.selectedClassId,
                decoration: const InputDecoration(labelText: 'Lớp môn'),
                items: [
                  for (final r in vm.rows)
                    DropdownMenuItem(
                      value: r.course.id,
                      child: Text('${r.course.title} · ${r.subject.name}'),
                    ),
                ],
                onChanged: (id) => vm.select(id!),
              ),
              const SizedBox(height: 12),
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
                              row.subject.name,
                              style: text.titleMedium,
                            ),
                          ),
                          StatusChip.course(row.result.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (row.record == null)
                        const Text('Điểm chưa được công bố.')
                      else ...[
                        for (final c in row.subject.components)
                          InfoRow(
                            '${c.name} (${c.weight.toStringAsFixed(0)}%)',
                            row.record!.marks[c.name]?.toStringAsFixed(1) ??
                                '-',
                          ),
                        const Divider(height: 24),
                        InfoRow(
                          'Trung bình',
                          row.result.average?.toStringAsFixed(1) ?? '-',
                        ),
                        if (row.result.reason.isNotEmpty)
                          InfoRow('Ghi chú', row.result.reason),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
