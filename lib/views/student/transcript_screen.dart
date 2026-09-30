import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/grade_repository.dart';
import '../../domain/grade_rules.dart';
import '../../viewmodels/student/results_view_model.dart';
import '../widgets/common.dart';
import 'grade_report_screen.dart';

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
        builder: (context) {
          final text = Theme.of(context).textTheme;
          final totalCredits = vm.rows.fold(
            0,
            (sum, r) => sum + r.subject.credits,
          );
          return ContentWidth(child: RefreshIndicator(
            onRefresh: () async {
              await vm.load();
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                HeroHeader(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tín chỉ đã tích luỹ',
                          style:
                              text.labelLarge?.copyWith(color: Colors.white70),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${vm.passedCredits}',
                            style: text.displayMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'trên tổng $totalCredits tín chỉ của ${vm.rows.length} môn',
                          style:
                              text.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Các môn học'),
                      for (final r in vm.rows)
                        _CourseCard(
                          row: r,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GradeReportScreen(
                                student: vm.student,
                                initialClassId: r.course.id,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ));
        },
      ),
    );
  }
}

Tone _toneOf(CourseStatus s) => switch (s) {
  CourseStatus.passed => Tone.good,
  CourseStatus.notPassed => Tone.bad,
  CourseStatus.studying => Tone.pending,
};

/// Một môn: vạch màu bên trái theo trạng thái, tên, dòng thông tin, chip.
/// Chạm để mở Điểm học kỳ của đúng môn, không phải chọn lại.
class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.row, required this.onTap});

  final CourseResultRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stripe = StatusColors.of(context).forTone(_toneOf(row.result.status)).$1;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${row.subject.code} · ${row.subject.name}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          '${row.course.semester} · ${row.subject.credits} tín chỉ · '
          'Điểm ${row.result.average?.toStringAsFixed(1) ?? '-'}',
          style: text.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: stripe, width: 6)),
          ),
          child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth <
                340 * MediaQuery.textScalerOf(context).scale(1);
            final status = Wrap(
              alignment: WrapAlignment.end,
              children: [StatusChip.course(row.result.status)],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 8),
                  status,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: details),
                const SizedBox(width: 8),
                Flexible(child: status),
              ],
            );
          },
          ),
        ),
      ),
    );
  }
}
