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
          builder: (_) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: vm.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _NotificationCard(vm.items[i]),
          ),
        ),
      ),
    );
  }

  Future<void> _compose(BuildContext context, NotificationsViewModel vm) async {
    final title = TextEditingController();
    final content = TextEditingController();
    var audience = Audience.all;
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
              SegmentedButton<Audience>(
                segments: [
                  for (final a in Audience.values)
                    ButtonSegment(value: a, label: Text(a.label)),
                ],
                selected: {audience},
                onSelectionChanged: (s) => setSheet(() => audience = s.first),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final ok = await vm.publish(
                    title.text,
                    content.text,
                    audience,
                  );
                  if (!sheet.mounted) return;
                  if (ok) Navigator.of(sheet).pop();
                  showResult(context, vm, 'Đã đăng thông báo');
                },
                child: const Text('Đăng'),
              ),
            ],
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
        title: Text(item.title, style: text.titleSmall),
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
