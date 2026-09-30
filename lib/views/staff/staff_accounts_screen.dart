import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/user_repository.dart';
import '../../viewmodels/staff/staff_accounts_view_model.dart';
import '../../app/app_theme.dart';
import '../widgets/common.dart';

/// Cán bộ đào tạo xem người dùng và mở tài khoản sinh viên / giảng viên.
///
/// Main wiring (không sửa home_shell trong ticket này):
/// ```dart
/// page: (_) => const StaffAccountsScreen(),
/// ```
class StaffAccountsScreen extends StatelessWidget {
  const StaffAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          StaffAccountsViewModel(context.read<UserRepository>())..load(),
      child: const _StaffAccountsView(),
    );
  }
}

class _StaffAccountsView extends StatefulWidget {
  const _StaffAccountsView();

  @override
  State<_StaffAccountsView> createState() => _StaffAccountsViewState();
}

class _StaffAccountsViewState extends State<_StaffAccountsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StaffAccountsViewModel>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý tài khoản')),
      body: AsyncBody(
        vm: vm,
        isEmpty: vm.filtered.isEmpty,
        emptyText: vm.query.trim().isEmpty
            ? 'Chưa có người dùng'
            : 'Không tìm thấy người dùng',
        onRetry: vm.load,
        builder: (context) => ContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Tìm theo tên, mã, email',
                    prefixIcon: Icon(Icons.search_outlined),
                  ),
                  onChanged: vm.setQuery,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButtonFormField<UserRole?>(
                  initialValue: vm.roleFilter,
                  // Chữ phóng to 2x trên màn 320dp: không cho nhãn đẩy tràn ngang.
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Vai trò'),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Tất cả', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: UserRole.student,
                      child: Text('Sinh viên', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: UserRole.lecturer,
                      child: Text(
                        'Giảng viên',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: vm.setRoleFilter,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: vm.load,
                  child: ListView.builder(
                    // Chừa chỗ cho nút "Tạo tài khoản" để dòng cuối không bị che.
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: vm.filtered.length,
                    itemBuilder: (context, i) {
                      final p = vm.filtered[i];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            p.role == UserRole.student
                                ? Icons.school_outlined
                                : Icons.person_outline,
                          ),
                          title: Text(
                            p.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                          // Nhãn vai trò nằm trong subtitle: để ở trailing thì
                          // tràn ngang khi chữ phóng to (màn 320dp, chữ 2x).
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.code} · ${p.email}'
                                '${p.department.isEmpty ? '' : ' · ${p.department}'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              StatusChip(
                                p.role.label,
                                p.role == UserRole.student
                                    ? Tone.pending
                                    : Tone.good,
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Tạo tài khoản'),
        onPressed: vm.busy
            ? null
            : () async {
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: vm,
                    child: const _CreateAccountDialog(),
                  ),
                );
                if (!context.mounted) return;
                if (created == true) {
                  showResult(context, vm, 'Đã tạo tài khoản');
                }
              },
      ),
    );
  }
}

class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog();

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  UserRole _role = UserRole.student;
  String _department = 'SE';
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StaffAccountsViewModel>();
    final isLecturer = _role == UserRole.lecturer;
    return AlertDialog(
      title: const Text('Tạo tài khoản'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: const [
                  DropdownMenuItem(
                    value: UserRole.student,
                    child: Text('Sinh viên'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.lecturer,
                    child: Text('Giảng viên'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _role = v ?? UserRole.student),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Họ tên'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Mã (VD HE170001)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _department,
                decoration: const InputDecoration(labelText: 'Bộ môn'),
                items: const [
                  DropdownMenuItem(value: 'SE', child: Text('SE')),
                  DropdownMenuItem(value: 'AI', child: Text('AI')),
                ],
                onChanged: isLecturer
                    ? (v) => setState(() => _department = v ?? 'SE')
                    : null,
              ),
              const SizedBox(height: 12),
              const Text(
                'Mật khẩu mặc định: ${StaffAccountsViewModel.newAccountPassword} '
                '— báo cho người dùng đổi sau khi đăng nhập.',
                style: TextStyle(fontSize: 12),
              ),
              if (vm.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  vm.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: vm.busy
              ? null
              : () async {
                  final ok = await vm.createAccount(
                    role: _role,
                    fullName: _name.text,
                    code: _code.text,
                    email: _email.text,
                    department: isLecturer ? _department : '',
                  );
                  if (!context.mounted) return;
                  if (ok) Navigator.of(context).pop(true);
                },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}
