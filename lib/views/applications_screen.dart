import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
          builder: (context) => ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: vm.items.length,
            itemBuilder: (context, i) => _ApplicationCard(vm.items[i], vm),
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
                    DropdownMenuItem(value: t, child: Text(t)),
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
              FilledButton(
                onPressed: () async {
                  final ok = await vm.submit(type, content.text);
                  if (!sheet.mounted) return;
                  if (ok) Navigator.of(sheet).pop();
                  showResult(context, vm, 'Đã gửi đơn');
                },
                child: const Text('Gửi'),
              ),
            ],
          ),
        ),
      ),
    );
    content.dispose();
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard(this.form, this.vm);

  final ApplicationForm form;
  final ApplicationsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canProcess =
        !vm.isStudent && form.status == ApplicationStatus.processing;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(form.type, style: text.titleSmall)),
                StatusChip.application(form.status),
              ],
            ),
            const SizedBox(height: 8),
            if (!vm.isStudent)
              InfoRow('Sinh viên', '${form.studentName} (${form.studentCode})'),
            InfoRow('Ngày gửi', _time.format(form.createdAt)),
            InfoRow('Nội dung', form.content),
            if (form.processedAt != null) ...[
              InfoRow('Người xử lý', form.processedBy),
              if (form.staffNote.isNotEmpty)
                InfoRow('Phản hồi', form.staffNote),
            ],
            if (canProcess) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _decide(context, ApplicationStatus.rejected),
                      child: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _decide(context, ApplicationStatus.approved),
                      child: const Text('Chấp nhận'),
                    ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          decision == ApplicationStatus.approved
              ? 'Chấp nhận đơn'
              : 'Từ chối đơn',
        ),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: decision == ApplicationStatus.approved
                ? 'Phản hồi (không bắt buộc)'
                : 'Lý do từ chối',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      note.dispose();
      return;
    }
    await vm.process(form, decision, note.text);
    note.dispose();
    if (!context.mounted) return;
    showResult(context, vm, 'Đã cập nhật đơn');
  }
}
