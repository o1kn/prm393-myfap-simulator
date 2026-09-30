import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../app/app_theme.dart';
import '../../data/models/app_user.dart';
import '../../viewmodels/auth_view_model.dart';
import '../applications_screen.dart';
import '../class_list_screen.dart';
import '../head/assignment_screen.dart';
import '../notifications_screen.dart';
import '../student/attendance_report_screen.dart';
import '../student/grade_report_screen.dart';
import '../student/transcript_screen.dart';
import '../timetable_screen.dart';
import '../widgets/common.dart';

/// Khung chính sau đăng nhập: 3 tab như myFAP gốc (Main / Messages / Profile).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeMenu(user: user),
          NotificationsScreen(user: user),
          _ProfileTab(user: user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: 'Thông báo',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

typedef _MenuItem = ({IconData icon, String label, WidgetBuilder page});

/// Lưới chức năng theo nhóm, giống trang chủ myFAP; mỗi vai trò một bộ.
List<(String, List<_MenuItem>)> _menuFor(AppUser user) => switch (user.role) {
  UserRole.student => [
    (
      'Lịch học',
      [
        (
          icon: Icons.calendar_view_week_outlined,
          label: 'Lịch học tuần',
          page: (_) => TimetableScreen(user: user),
        ),
      ],
    ),
    (
      'Điểm danh, điểm',
      [
        (
          icon: Icons.fact_check_outlined,
          label: 'Điểm danh',
          page: (_) => AttendanceReportScreen(student: user),
        ),
        (
          icon: Icons.grading_outlined,
          label: 'Điểm học kỳ',
          page: (_) => GradeReportScreen(student: user),
        ),
        (
          icon: Icons.school_outlined,
          label: 'Bảng điểm',
          page: (_) => TranscriptScreen(student: user),
        ),
      ],
    ),
    (
      'Đơn từ',
      [
        (
          icon: Icons.description_outlined,
          label: 'Đơn từ',
          page: (_) => ApplicationsScreen(user: user),
        ),
      ],
    ),
  ],
  UserRole.lecturer => [
    (
      'Giảng dạy',
      [
        (
          icon: Icons.calendar_view_week_outlined,
          label: 'Lịch dạy & điểm danh',
          page: (_) => TimetableScreen(user: user),
        ),
        (
          icon: Icons.edit_note_outlined,
          label: 'Nhập điểm',
          page: (_) => ClassListScreen(user: user),
        ),
      ],
    ),
  ],
  UserRole.head => [
    (
      'Bộ môn ${user.department}',
      [
        (
          icon: Icons.assignment_ind_outlined,
          label: 'Phân công giảng viên',
          page: (_) => AssignmentScreen(head: user),
        ),
        (
          icon: Icons.verified_outlined,
          label: 'Duyệt bảng điểm',
          page: (_) => ClassListScreen(user: user),
        ),
      ],
    ),
  ],
  UserRole.staff => [
    (
      'Đào tạo',
      [
        (
          icon: Icons.class_outlined,
          label: 'Lớp môn & lịch học',
          page: (_) => ClassListScreen(user: user),
        ),
        (
          icon: Icons.inbox_outlined,
          label: 'Xử lý đơn từ',
          page: (_) => ApplicationsScreen(user: user),
        ),
      ],
    ),
  ],
};

class _HomeMenu extends StatelessWidget {
  const _HomeMenu({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('myFAP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UserCard(user: user),
          for (final (title, items) in _menuFor(user)) ...[
            const SizedBox(height: 20),
            Text(title, style: text.titleMedium),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [for (final item in items) _MenuTile(item: item)],
            ),
          ],
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fapNavy,
        borderRadius: BorderRadius.circular(appRadius),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF39200),
            foregroundColor: Colors.white,
            child: Text(user.fullName.split(' ').last[0]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    user.code,
                    user.role.label,
                    if (user.department.isNotEmpty) 'Bộ môn ${user.department}',
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: item.page)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: scheme.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow('Họ tên', user.fullName),
                  InfoRow('Mã', user.code),
                  InfoRow('Email', user.email),
                  InfoRow('Vai trò', user.role.label),
                  if (user.department.isNotEmpty)
                    InfoRow('Bộ môn', user.department),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
            onPressed: () async {
              await context.read<AuthViewModel>().signOut();
              if (!context.mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(Routes.login, (_) => false);
            },
          ),
        ],
      ),
    );
  }
}
