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
            width: 140,
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

/// Giới hạn bề rộng nội dung và căn giữa: máy tính bảng / màn xoay ngang
/// không bị kéo giãn, điện thoại nhỏ vẫn dùng đủ chiều ngang.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: child,
    ),
  );
}

/// Nhãn nhóm viết hoa nhỏ đặt phía trên một cụm nội dung.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Khung navy bo tròn phía dưới, nối liền thanh tiêu đề. Chứa phần tóm tắt
/// của màn hình (lời chào, kết quả, cảnh báo). [underStatusBar] chừa chỗ cho
/// thanh trạng thái khi màn hình không có AppBar.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.child, this.underStatusBar = false});

  final Widget child;
  final bool underStatusBar;

  @override
  Widget build(BuildContext context) {
    final top = underStatusBar ? MediaQuery.paddingOf(context).top : 0.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 24),
      decoration: const BoxDecoration(
        color: fapNavy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: child,
    );
  }
}

/// Ô số liệu lớn: con số nổi bật + nhãn. [highlight] tô cam khi cần chú ý.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = highlight ? scheme.onPrimary : scheme.onSurface;
    return Card(
      color: highlight ? scheme.primary : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: highlight ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hàng ô số liệu. Đủ chỗ thì xếp ngang cho gọn; khi chữ được phóng to
/// (trợ năng) thì tự xếp dọc, nếu không nhãn dài như "Buổi học hôm nay" sẽ bị
/// cắt thành "Buổi học h...".
class StatRow extends StatelessWidget {
  const StatRow(this.tiles, {super.key});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    // Chữ phóng to từ 1,5 lần trở lên thì hai ô cạnh nhau không còn đủ chỗ.
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.5) {
      return Column(
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            tile,
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: tile),
          ],
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
