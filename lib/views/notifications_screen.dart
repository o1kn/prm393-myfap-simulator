import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/models/app_notification.dart';
import '../data/models/app_user.dart';
import '../data/repositories/notification_repository.dart';
import '../viewmodels/notifications_view_model.dart';
import 'widgets/common.dart';

final _time = DateFormat('dd/MM/yyyy HH:mm');

/// Thông báo. Cán bộ đào tạo có thêm nút đăng thông báo.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          NotificationsViewModel(context.read<NotificationRepository>(), user)
            ..load(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      floatingActionButton: vm.canPublish
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Đăng thông báo'),
              onPressed: () => _compose(context, vm),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: AsyncBody(
          vm: vm,
          isEmpty: vm.items.isEmpty,
          emptyText: 'Chưa có thông báo',
          onRetry: vm.load,
          builder: (_) => ContentWidth(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: vm.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _NotificationCard(vm.items[i]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _compose(BuildContext context, NotificationsViewModel vm) async {
    final title = TextEditingController();
    final content = TextEditingController();
    var audience = Audience.all;
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
              Text(
                'Đăng thông báo',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: content,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Nội dung'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in Audience.values)
                    ChoiceChip(
                      label: Text(a.label),
                      selected: audience == a,
                      onSelected: (_) => setSheet(() => audience = a),
                    ),
                ],
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
                  final ok = await vm.publish(
                    title.text,
                    content.text,
                    audience,
                  );
                  if (!sheet.mounted) return;
                  if (!ok) {
                    setSheet(() => error = vm.error);
                    return;
                  }
                  Navigator.of(sheet).pop();
                  showResult(context, vm, 'Đã đăng thông báo');
                },
                child: const Text('Đăng'),
              ),
            ],
          ),
          ),
        ),
      ),
    );
    title.dispose();
    content.dispose();
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard(this.item);

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: Icon(switch (item.audience) {
            Audience.all => Icons.campaign_outlined,
            Audience.students => Icons.school_outlined,
            Audience.lecturers => Icons.co_present_outlined,
          }),
        ),
        title: Text(
          item.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_time.format(item.createdAt)} · ${item.authorName} · '
          '${item.audience.label}',
          style: text.bodySmall?.copyWith(color: muted),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.centerLeft,
        children: [Text(item.content)],
      ),
    );
  }
}
