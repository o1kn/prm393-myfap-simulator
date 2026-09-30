import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/grade_repository.dart';
import '../../viewmodels/student/results_view_model.dart';
import '../widgets/common.dart';

/// Academic transcript: mọi môn, tín chỉ, điểm và trạng thái.
class TranscriptScreen extends StatelessWidget {
  const TranscriptScreen({super.key, required this.student});

  final AppUser student;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ResultsViewModel(
        context.read<AcademicRepository>(),
        context.read<GradeRepository>(),
        student,
      )..load(),
      child: const _TranscriptView(),
    );
  }
}

class _TranscriptView extends StatelessWidget {
  const _TranscriptView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResultsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng điểm')),
      body: AsyncBody(
        vm: vm,
        isEmpty: vm.rows.isEmpty,
        emptyText: 'Chưa có môn học',
        onRetry: vm.load,
        builder: (context) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Tín chỉ đã tích luỹ: ${vm.passedCredits}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final r in vm.rows)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${r.subject.code} · ${r.subject.name}'),
                  subtitle: Text(
                    '${r.course.semester} · ${r.subject.credits} tín chỉ · '
                    'Điểm ${r.result.average?.toStringAsFixed(1) ?? '-'}',
                  ),
                  trailing: StatusChip.course(r.result.status),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
