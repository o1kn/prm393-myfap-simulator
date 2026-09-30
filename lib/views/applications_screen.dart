import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../core/constants.dart';
import '../data/models/app_user.dart';
import '../data/models/application_form.dart';
import '../data/repositories/application_repository.dart';
import '../viewmodels/applications_view_model.dart';
import 'widgets/common.dart';

final _time = DateFormat('dd/MM/yyyy HH:mm');

/// Đơn từ. Sinh viên: xem đơn của mình + gửi đơn. Cán bộ đào tạo: xử lý đơn.
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ApplicationsViewModel(context.read<ApplicationRepository>(), user)
            ..load(),
      child: const _ApplicationsView(),
    );
  }
}

class _ApplicationsView extends StatelessWidget {
  const _ApplicationsView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ApplicationsViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          vm.isStudent ? 'Đơn từ' : 'Xử lý đơn từ (${vm.pendingCount} chờ)',
        ),
      ),
      floatingActionButton: vm.isStudent
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Gửi đơn'),
              onPressed: () => _submitSheet(context, vm),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: AsyncBody(
          vm: vm,
          isEmpty: vm.items.isEmpty,
          emptyText: 'Chưa có đơn từ',
          onRetry: vm.load,
          builder: (context) => ContentWidth(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: vm.items.length,
              itemBuilder: (context, i) => _ApplicationCard(vm.items[i], vm),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSheet(
    BuildContext context,
    ApplicationsViewModel vm,
  ) async {
    final content = TextEditingController();
    var type = applicationTypes.first;
    // Lỗi hiện ngay trong sheet: SnackBar nằm dưới lớp modal nên bị che.
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Gửi đơn', style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Loại đơn'),
                  items: [
                    for (final t in applicationTypes)
                      DropdownMenuItem(
                        value: t,
                        child: Text(
                          t,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setSheet(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('application-content'),
                  controller: content,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung / lý do',
                  ),
                ),
                const SizedBox(height: 16),
                if (error != null) ...[
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(sheet).colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: () async {
                    final ok = await vm.submit(type, content.text);
                    if (!sheet.mounted) return;
                    if (!ok) {
                      setSheet(() => error = vm.error);
                      return;
                    }
                    Navigator.of(sheet).pop();
                    showResult(context, vm, 'Đã gửi đơn');
                  },
                  child: const Text('Gửi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    content.dispose();
  }
}

/// Biểu tượng theo loại đơn; loại lạ (do dữ liệu cũ) dùng biểu tượng chung.
IconData _typeIcon(String type) => switch (type) {
  'Xin chuyển lớp học' => Icons.swap_horiz,
  'Xin tạm nghỉ một học kỳ' => Icons.pause_circle_outline,
  'Xác nhận sinh viên' => Icons.badge_outlined,
  'Xác nhận sinh viên để hoãn nghĩa vụ quân sự' => Icons.shield_outlined,
  'Xác nhận vay vốn ngân hàng' => Icons.account_balance_outlined,
  'Hủy đăng ký học lại' => Icons.event_busy_outlined,
  _ => Icons.description_outlined,
};

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard(this.form, this.vm);

  final ApplicationForm form;
  final ApplicationsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final canProcess =
        !vm.isStudent && form.status == ApplicationStatus.processing;
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
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Icon(_typeIcon(form.type)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.type,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (!vm.isStudent)
                        Text(
                          'Sinh viên: ${form.studentName} (${form.studentCode})',
                          style: muted,
                        ),
                      Text(
                        'Ngày gửi: ${_time.format(form.createdAt)}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(children: [StatusChip.application(form.status)]),
            ),
            const SizedBox(height: 8),
            Text('Nội dung', style: muted),
            Text(form.content, style: text.bodyMedium),
            if (form.processedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Người xử lý: ${form.processedBy} · '
                '${_time.format(form.processedAt!)}',
                style: muted,
              ),
              if (form.staffNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(tagRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phản hồi',
                        style: text.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        form.staffNote,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (canProcess) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        _decide(context, ApplicationStatus.rejected),
                    child: const Text('Từ chối'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        _decide(context, ApplicationStatus.approved),
                    child: const Text('Chấp nhận'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, ApplicationStatus decision) async {
    final note = TextEditingController();
    String? error;
    var saving = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) => AlertDialog(
          scrollable: true,
          title: Text(
            decision == ApplicationStatus.approved
                ? 'Chấp nhận đơn'
                : 'Từ chối đơn',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: note,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: decision == ApplicationStatus.approved
                      ? 'Phản hồi (không bắt buộc)'
                      : 'Lý do từ chối',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(dialog).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialog, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: saving ? null : () async {
                setDialog(() => saving = true);
                final ok = await vm.process(form, decision, note.text);
                if (!dialog.mounted) return;
                if (!ok) {
                  setDialog(() {
                    saving = false;
                    error = vm.error;
                  });
                  return;
                }
                Navigator.pop(dialog, true);
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    if (confirmed != true || !context.mounted) return;
    showResult(context, vm, 'Đã cập nhật đơn');
  }
}
