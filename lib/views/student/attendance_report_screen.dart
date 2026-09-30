import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/constants.dart';
import '../../data/models/app_user.dart';
import '../../data/models/class_session.dart';
import '../../data/repositories/academic_repository.dart';
import '../../domain/attendance_rules.dart';
import '../../viewmodels/student/attendance_report_view_model.dart';
import '../widgets/common.dart';

/// Attendance report: chọn lớp môn, xem từng buổi và tỉ lệ vắng.
/// [initialClassId] preselect khi mở từ Điểm học kỳ, giữ nguyên khi refresh.
class AttendanceReportScreen extends StatelessWidget {
  const AttendanceReportScreen({super.key, required this.student, this.initialClassId});

  final AppUser student;
  final String? initialClassId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AttendanceReportViewModel(
        context.read<AcademicRepository>(),
        student,
        initialClassId: initialClassId,
      )..load(),
      child: const _AttendanceView(),
    );
  }
}

/// Thanh tỉ lệ vắng chạy từ 0% đến gấp đôi ngưỡng cho phép, vạch trắng ở
/// đúng ngưỡng 20% (giữa thanh). Vượt vạch là bị cấm thi.
const _barScale = maxAbsentRate * 2;

/// Màu tốt / sắp chạm ngưỡng / vượt ngưỡng của buổi vắng.
Tone _toneOf(AttendanceSummary summary) {
  if (summary.isBanned) return Tone.bad;
  if (summary.absentRate >= maxAbsentRate * 0.75) return Tone.pending;
  return Tone.good;
}

/// Số buổi được phép vắng tối đa mà chưa bị cấm thi (vắng *vượt* 20% mới cấm,
/// nên đúng 20% vẫn an toàn). Tổng tính trên các buổi đã xếp cho sinh viên,
/// gồm cả buổi chưa diễn ra.
int _maxAllowedAbsent(AttendanceSummary s) =>
    (maxAbsentRate * s.total).floor();

/// Số buổi còn được phép vắng thêm trước khi chạm ngưỡng cấm thi.
int _remainingAbsent(AttendanceSummary s) {
  if (s.total == 0) return 0;
  final remaining = _maxAllowedAbsent(s) - s.absent;
  return remaining < 0 ? 0 : remaining;
}

/// Buổi tương lai chưa diễn ra: ngày học từ hôm nay trở đi và cả buổi chưa
/// có điểm danh cho ai. Ngày quá khứ mà chưa có điểm danh là "chưa điểm danh",
/// khác với buổi tương lai "chưa diễn ra".
bool _isUpcoming(ClassSession session) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return !session.date.isBefore(today) && session.attendance.isEmpty;
}

/// Nhãn trạng thái phân biệt quá khứ chưa ghi nhận với tương lai chưa tới.
String _sessionLabel(ClassSession session, AttendanceStatus status) {
  if (status != AttendanceStatus.notYet) return status.label;
  return _isUpcoming(session) ? 'Chưa diễn ra' : 'Chưa điểm danh';
}

class _AttendanceView extends StatelessWidget {
  const _AttendanceView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AttendanceReportViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Điểm danh')),
      body: AsyncBody(
        vm: vm,
        isEmpty: vm.classes.isEmpty,
        emptyText: 'Bạn chưa có lớp môn nào trong kỳ',
        onRetry: vm.load,
        builder: (context) {
          final summary = vm.summary;
          final tone = _toneOf(summary);
          final sessions = vm.sessions;
          var futureCount = 0;
          var unrecordedCount = 0;
          for (final s in sessions) {
            if (s.statusOf(vm.student.uid) == AttendanceStatus.notYet) {
              if (_isUpcoming(s)) {
                futureCount++;
              } else {
                unrecordedCount++;
              }
            }
          }
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
                            for (final c in vm.classes)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  '${c.title} · ${c.subjectName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) => vm.select(id!),
                        ),
                        const SizedBox(height: 20),
                        _AbsentHero(summary: summary, tone: tone),
                      ],
                    ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Tổng quan các môn'),
                      for (final c in vm.classes)
                        _OverviewCard(
                          title: '${c.title} · ${c.subjectName}',
                          summary: vm.summaryFor(c.id),
                          selected: c.id == vm.selectedClassId,
                          onTap: () => vm.select(c.id),
                        ),
                      const SizedBox(height: 8),
                      _SummaryBanner(
                        summary: summary,
                        tone: tone,
                        futureCount: futureCount,
                        unrecordedCount: unrecordedCount,
                      ),
                      SectionLabel('Các buổi học (${sessions.length})'),
                      for (final s in sessions)
                        _SessionCard(
                          session: s,
                          status: s.statusOf(vm.student.uid),
                          displayLabel: _sessionLabel(
                            s,
                            s.statusOf(vm.student.uid),
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

/// Phần số lớn trong khung navy: % vắng, chú thích và thanh ngưỡng.
class _AbsentHero extends StatelessWidget {
  const _AbsentHero({required this.summary, required this.tone});

  final AttendanceSummary summary;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Nền khung luôn là navy nên dùng bảng màu sáng (chế độ tối) cho thanh.
    final (barColor, _) = StatusColors.dark.forTone(tone);
    final fill = (summary.absentRate / _barScale).clamp(0.0, 1.0);
    final limitPercent = (maxAbsentRate * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tỉ lệ vắng',
          style: text.labelLarge?.copyWith(color: Colors.white70),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '${(summary.absentRate * 100).round()}%',
            style: text.displayMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${summary.absent}/${summary.total} buổi vắng · '
          'tối đa $limitPercent%',
          style: text.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        // Thanh: nền mờ, phần tô theo % vắng, vạch trắng đứng ở ngưỡng 20%.
        SizedBox(
          height: 14,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fill,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment((maxAbsentRate / _barScale) * 2 - 1, 0),
                child: Container(width: 3, height: 14, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vạch trắng: ngưỡng $limitPercent%',
          style: text.labelMedium?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

/// Dòng tóm tắt + cảnh báo, nền nhạt theo màu trạng thái.
/// Phân biệt buổi tương lai chưa diễn ra với buổi quá khứ chưa ghi nhận.
class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.summary,
    required this.tone,
    required this.futureCount,
    required this.unrecordedCount,
  });

  final AttendanceSummary summary;
  final Tone tone;
  final int futureCount;
  final int unrecordedCount;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = StatusColors.of(context).forTone(tone);
    final banned = summary.isBanned;
    final remaining = _remainingAbsent(summary);
    final breakdown = switch ((futureCount, unrecordedCount)) {
      (0, 0) => 'Đã ghi nhận đủ các buổi đã qua.',
      (_, 0) => '$futureCount buổi chưa diễn ra.',
      (0, _) => '$unrecordedCount buổi quá khứ chưa có điểm danh.',
      (_, _) =>
        '$futureCount buổi chưa diễn ra · $unrecordedCount buổi quá khứ chưa có điểm danh.',
    };
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
          Icon(
            tone == Tone.good
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            color: fg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vắng ${(summary.absentRate * 100).round()}% '
              '(${summary.absent}/${summary.total} buổi, tính trên các buổi đã xếp gồm cả buổi chưa diễn ra), '
              'còn $remaining buổi được phép vắng thêm. $breakdown'
              '${banned ? '\nVượt 20%: không đủ điều kiện dự thi.' : ''}',
              style: TextStyle(
                color: fg,
                fontWeight: banned ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ tổng quan một môn: vắng/tổng + số buổi còn được phép vắng.
/// Chạm để xem chi tiết cùng màn hình, không phải chọn lại từ dropdown.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final AttendanceSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = _toneOf(summary);
    final label = summary.isBanned
        ? 'Cấm thi'
        : summary.total == 0
            ? 'Chưa xếp buổi'
            : 'Còn ${_remainingAbsent(summary)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: selected
          ? RoundedRectangleBorder(
              side: BorderSide(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(appRadius),
            )
          : null,
      child: ListTile(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Vắng ${summary.absent}/${summary.total} '
          '(${(summary.absentRate * 100).round()}%)',
        ),
        trailing: StatusChip(label, tone),
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}

/// Một buổi học: số buổi trong vòng tròn, ngày/slot, giờ, phòng + GV, trạng thái.
/// [displayLabel] phân biệt "Chưa điểm danh" (quá khứ chưa ghi nhận) với
/// "Chưa diễn ra" (tương lai), vì model chỉ có một giá trị notYet.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.status,
    required this.displayLabel,
  });

  final ClassSession session;
  final AttendanceStatus status;
  final String displayLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final tone = switch (status) {
      AttendanceStatus.present => Tone.good,
      AttendanceStatus.absent => Tone.bad,
      AttendanceStatus.notYet => Tone.pending,
    };
    final (fg, bg) = StatusColors.of(context).forTone(tone);
    final number = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        '${session.sessionNo}',
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.dateKey.split('-').reversed.join('/'),
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          'Slot ${session.slot} · ${session.slotTime}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: muted,
        ),
        Text(
          'Phòng ${session.room}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: muted,
        ),
        Text(
          'GV ${session.lecturerName ?? '-'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: muted,
        ),
      ],
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Chữ lớn / màn hẹp: trạng thái không lấy mất bề rộng phòng, giờ.
            final compact = constraints.maxWidth <
                340 * MediaQuery.textScalerOf(context).scale(1);
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: number),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          children: [StatusChip(displayLabel, tone)],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: number),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: details),
                const SizedBox(width: 8),
                Flexible(
                  flex: 3,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    children: [StatusChip(displayLabel, tone)],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
