import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/subject.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/grade_repository.dart';
import '../../domain/grade_rules.dart';
import '../../viewmodels/student/results_view_model.dart';
import 'attendance_report_screen.dart';
import '../widgets/common.dart';

/// Grade report: điểm thành phần của một lớp môn (chỉ khi đã công bố).
/// [initialClassId] preselect khi mở từ Bảng điểm, giữ nguyên khi refresh.
class GradeReportScreen extends StatelessWidget {
  const GradeReportScreen({super.key, required this.student, this.initialClassId});

  final AppUser student;
  final String? initialClassId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ResultsViewModel(
        context.read<AcademicRepository>(),
        context.read<GradeRepository>(),
        student,
        initialClassId: initialClassId,
      )..load(),
      child: _GradeReportView(student: student),
    );
  }
}

class _GradeReportView extends StatelessWidget {
  const _GradeReportView({required this.student});

  final AppUser student;

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
                        DropdownButtonFormField<String>(
                          key: ValueKey(vm.selectedClassId),
                          initialValue: vm.selectedClassId,
                          isExpanded: true,
                          itemHeight: null,
                          decoration:
                              const InputDecoration(labelText: 'Lớp môn'),
                          items: [
                            for (final r in vm.rows)
                              DropdownMenuItem(
                                value: r.course.id,
                                child: Text(
                                  '${r.course.title} · ${r.subject.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) => vm.select(id!),
                        ),
                        const SizedBox(height: 20),
                        _AverageHero(row: row),
                      ],
                    ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (row.record == null)
                        const _NotPublished()
                      else
                        _Components(row: row),
                      const SizedBox(height: 8),
                      _AttendanceLink(
                        student: student,
                        classId: row.course.id,
                        courseTitle:
                            '${row.course.title} · ${row.subject.name}',
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

/// Tên môn, điểm trung bình thật lớn và trạng thái, trong khung navy.
class _AverageHero extends StatelessWidget {
  const _AverageHero({required this.row});

  final CourseResultRow row;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final average = row.result.average;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.subject.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Trung bình',
          style: text.labelLarge?.copyWith(color: Colors.white70),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  average?.toStringAsFixed(1) ?? '-',
                  style: text.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            if (average != null)
              Text(
                ' / 10',
                style: text.titleMedium?.copyWith(color: Colors.white70),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(children: [StatusChip.course(row.result.status)]),
      ],
    );
  }
}

/// Trạng thái "chưa công bố": biểu tượng + một dòng giải thích.
class _NotPublished extends StatelessWidget {
  const _NotPublished();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 48, color: muted),
          const SizedBox(height: 12),
          Text(
            'Điểm chưa được công bố.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ghi chú (lý do trượt) và danh sách điểm thành phần.
class _Components extends StatelessWidget {
  const _Components({required this.row});

  final CourseResultRow row;

  @override
  Widget build(BuildContext context) {
    final reason = row.result.reason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ReasonBanner(reason),
        ],
        const SectionLabel('Điểm thành phần'),
        for (final c in row.subject.components)
          _ComponentCard(component: c, mark: row.record!.marks[c.name]),
      ],
    );
  }
}

class _ReasonBanner extends StatelessWidget {
  const _ReasonBanner(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = StatusColors.of(context).forTone(Tone.bad);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(appRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ghi chú: $reason',
              style: TextStyle(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một đầu điểm: tên, trọng số, điểm và thanh điểm/10.
class _ComponentCard extends StatelessWidget {
  const _ComponentCard({required this.component, required this.mark});

  final GradeComponent component;
  final double? mark;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Bài thi cuối kỳ dưới điểm sàn thì thanh đỏ.
    final failedFinal =
        component.isFinal && mark != null && mark! < minFinalMark;
    final barColor = failedFinal
        ? StatusColors.of(context).forTone(Tone.bad).$1
        : scheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        component.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Trọng số ${component.weight.toStringAsFixed(0)}%',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    mark?.toStringAsFixed(1) ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineSmall?.copyWith(
                      color: failedFinal ? barColor : scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ((mark ?? 0) / 10).clamp(0.0, 1.0),
                minHeight: 6,
                color: barColor,
                backgroundColor: scheme.surfaceContainerHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút mở Điểm danh của đúng lớp đang xem, giữ lựa chọn khi sang màn mới.
class _AttendanceLink extends StatelessWidget {
  const _AttendanceLink({
    required this.student,
    required this.classId,
    required this.courseTitle,
  });

  final AppUser student;
  final String classId;
  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text('Xem điểm danh môn này'),
        subtitle: Text(
          courseTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AttendanceReportScreen(
              student: student,
              initialClassId: classId,
            ),
          ),
        ),
      ),
    );
  }
}
