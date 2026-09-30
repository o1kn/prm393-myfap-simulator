import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../viewmodels/staff/create_class_view_model.dart';
import '../widgets/common.dart';

const _weekdayLabels = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7'};

/// Cán bộ đào tạo mở lớp môn và xếp lịch cho cả kỳ.
class CreateClassScreen extends StatelessWidget {
  const CreateClassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CreateClassViewModel(
        context.read<AcademicRepository>(),
        context.read<UserRepository>(),
      )..load(),
      child: const _CreateClassView(),
    );
  }
}

class _CreateClassView extends StatefulWidget {
  const _CreateClassView();

  @override
  State<_CreateClassView> createState() => _CreateClassViewState();
}

class _CreateClassViewState extends State<_CreateClassView> {
  final _code = TextEditingController();
  final _room = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateClassViewModel>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mở lớp môn')),
      body: AsyncBody(
        vm: vm,
        isEmpty: vm.subjects.isEmpty,
        emptyText: 'Chưa có môn học',
        onRetry: vm.load,
        builder: (context) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            DropdownButtonFormField(
              initialValue: vm.subject,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Môn học'),
              items: [
                for (final s in vm.subjects)
                  DropdownMenuItem(
                    value: s,
                    child: Text(
                      '${s.code} · ${s.name} (${s.totalSessions} buổi)',
                    ),
                  ),
              ],
              onChanged: vm.setSubject,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Mã lớp',
                      hintText: 'SE1950',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _room,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Phòng',
                      hintText: 'BE-301',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Lịch học', style: text.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text(
                'Bắt đầu: ${DateFormat('dd/MM/yyyy').format(vm.startDate)}',
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: vm.startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 60)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) vm.setStartDate(picked);
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _weekdayLabels.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: vm.weekdays.contains(e.key),
                    onSelected: (_) => vm.toggleWeekday(e.key),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final e in slotTimes.entries)
                  ChoiceChip(
                    label: Text('Slot ${e.key} · ${e.value}'),
                    selected: vm.slot == e.key,
                    onSelected: (_) => vm.setSlot(e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Sinh viên (${vm.selectedStudents.length} đã chọn)',
              style: text.titleSmall,
            ),
            for (final s in vm.students)
              CheckboxListTile(
                value: vm.selectedStudents.contains(s.uid),
                onChanged: (_) => vm.toggleStudent(s.uid),
                title: Text(s.fullName),
                subtitle: Text(s.code),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: vm.busy
                ? null
                : () async {
                    final ok = await vm.create(
                      classCode: _code.text,
                      room: _room.text,
                    );
                    if (!context.mounted) return;
                    showResult(context, vm, 'Đã mở lớp và xếp lịch');
                    if (ok) Navigator.of(context).pop(true);
                  },
            child: const Text('Mở lớp & xếp lịch'),
          ),
        ),
      ),
    );
  }
}
