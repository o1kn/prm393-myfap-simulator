import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models/application_form.dart';
import '../../data/models/class_session.dart';
import '../../data/models/course_class.dart';
import '../../domain/grade_rules.dart';
import '../../viewmodels/base_view_model.dart';

/// Nhãn trạng thái nhỏ, màu theo [Tone].
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.tone, {super.key});

  factory StatusChip.attendance(AttendanceStatus s) =>
      StatusChip(s.label, switch (s) {
        AttendanceStatus.present => Tone.good,
        AttendanceStatus.absent => Tone.bad,
        AttendanceStatus.notYet => Tone.pending,
      });

  factory StatusChip.application(ApplicationStatus s) =>
      StatusChip(s.label, switch (s) {
        ApplicationStatus.processing => Tone.pending,
        ApplicationStatus.approved => Tone.good,
        ApplicationStatus.rejected => Tone.bad,
      });

  factory StatusChip.grade(GradeStatus s) => StatusChip(s.label, switch (s) {
    GradeStatus.published => Tone.good,
    GradeStatus.returned => Tone.bad,
    GradeStatus.draft || GradeStatus.submitted => Tone.pending,
  });

  factory StatusChip.course(CourseStatus s) => StatusChip(s.label, switch (s) {
    CourseStatus.passed => Tone.good,
    CourseStatus.notPassed => Tone.bad,
    CourseStatus.studying => Tone.pending,
  });

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = StatusColors.of(context).forTone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tagRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Khung chung cho nội dung tải từ Firestore: đang tải / lỗi (có nút thử
/// lại) / rỗng / nội dung.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.vm,
    required this.isEmpty,
    required this.emptyText,
    required this.onRetry,
    required this.builder,
  });

  final BaseViewModel vm;
  final bool isEmpty;
  final String emptyText;
  final VoidCallback onRetry;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (vm.busy && isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null && isEmpty) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        text: vm.error!,
        action: OutlinedButton(
          onPressed: onRetry,
          child: const Text('Thử lại'),
        ),
      );
    }
    if (isEmpty) {
      return _Message(icon: Icons.inbox_outlined, text: emptyText);
    }
    return builder(context);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Dòng "nhãn: giá trị" trong thẻ chi tiết.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

/// Hiện lỗi / thông báo thành công của một thao tác ghi.
void showResult(BuildContext context, BaseViewModel vm, String success) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(vm.error ?? success)));
}
