import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../app/app_theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/class_session.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/application_repository.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/home_view_model.dart';
import '../applications_screen.dart';
import '../class_list_screen.dart';
import '../head/assignment_screen.dart';
import '../notifications_screen.dart';
import '../student/attendance_report_screen.dart';
import '../student/grade_report_screen.dart';
import '../student/transcript_screen.dart';
import '../staff/staff_accounts_screen.dart';
import '../timetable_screen.dart';
import '../widgets/common.dart';

const _weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];

String _two(int n) => n.toString().padLeft(2, '0');

String _dateLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_two(d.day)}/${_two(d.month)}/${d.year}';

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
    return ChangeNotifierProvider(
      key: ValueKey(user.uid),
      create: (c) => HomeViewModel(
        c.read<AcademicRepository>(),
        c.read<ApplicationRepository>(),
        user,
      )..load(),
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            _HomeTab(user: user),
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
              selectedIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Thông báo',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Trang chủ

/// Mỗi chức năng: biểu tượng, tên, mô tả một dòng, số việc đang chờ (huy hiệu).
typedef _MenuItem = ({
  IconData icon,
  String label,
  String hint,
  int badge,
  WidgetBuilder page,
});

/// Nhóm chức năng theo vai trò, giống trang chủ myFAP; huy hiệu lấy từ [vm].
List<(String, List<_MenuItem>)> _menuFor(AppUser user, HomeViewModel vm) =>
    switch (user.role) {
      UserRole.student => [
        (
          'Lịch học',
          [
            (
              icon: Icons.calendar_view_week_outlined,
              label: 'Lịch học tuần',
              hint: 'Buổi học và trạng thái điểm danh',
              badge: 0,
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
              hint: 'Số buổi vắng từng môn, cảnh báo quá 20%',
              badge: 0,
              page: (_) => AttendanceReportScreen(student: user),
            ),
            (
              icon: Icons.grading_outlined,
              label: 'Điểm học kỳ',
              hint: 'Điểm thành phần và kết quả từng môn',
              badge: 0,
              page: (_) => GradeReportScreen(student: user),
            ),
            (
              icon: Icons.school_outlined,
              label: 'Bảng điểm',
              hint: 'Các môn đã học và tín chỉ tích luỹ',
              badge: 0,
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
              hint: 'Gửi đơn và theo dõi kết quả xử lý',
              badge: vm.pendingApplications,
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
              hint: 'Chọn buổi học để điểm danh',
              badge: 0,
              page: (_) => TimetableScreen(user: user),
            ),
            (
              icon: Icons.edit_note_outlined,
              label: 'Nhập điểm',
              hint: 'Lưu nháp rồi gửi trưởng bộ môn duyệt',
              badge: vm.gradesToEnter,
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
              hint: 'Gán giảng viên cho lớp chưa có người dạy',
              badge: vm.unassignedClasses,
              page: (_) => AssignmentScreen(head: user),
            ),
            (
              icon: Icons.verified_outlined,
              label: 'Duyệt bảng điểm',
              hint: 'Công bố hoặc trả lại bảng điểm giảng viên gửi',
              badge: vm.gradesToApprove,
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
              hint: 'Mở lớp, xếp lịch, kiểm tra trùng phòng',
              badge: 0,
              page: (_) => ClassListScreen(user: user),
            ),
            (
              icon: Icons.inbox_outlined,
              label: 'Xử lý đơn từ',
              hint: 'Chấp nhận hoặc từ chối đơn của sinh viên',
              badge: vm.pendingApplications,
              page: (_) => ApplicationsScreen(user: user),
            ),
          ],
        ),
        (
          'Người dùng',
          [
            (
              icon: Icons.manage_accounts_outlined,
              label: 'Quản lý tài khoản',
              hint: 'Mở tài khoản sinh viên / giảng viên mới',
              badge: 0,
              page: (_) => const StaffAccountsScreen(),
            ),
          ],
        ),
      ],
    };

/// Hai ô số liệu "việc cần làm ngay" theo vai trò: (nhãn, giá trị, tô cam).
List<(String, int, bool)> _statsFor(UserRole role, HomeViewModel vm) =>
    switch (role) {
      UserRole.student => [
        ('Buổi học hôm nay', vm.todaySessions, false),
        ('Đơn đang xử lý', vm.pendingApplications, false),
      ],
      UserRole.lecturer => [
        ('Buổi dạy hôm nay', vm.todaySessions, false),
        ('Bảng điểm cần nhập', vm.gradesToEnter, vm.gradesToEnter > 0),
      ],
      UserRole.head => [
        ('Chờ duyệt điểm', vm.gradesToApprove, vm.gradesToApprove > 0),
        ('Lớp chưa có GV', vm.unassignedClasses, vm.unassignedClasses > 0),
      ],
      UserRole.staff => [
        (
          'Đơn đang xử lý',
          vm.pendingApplications,
          vm.pendingApplications > 0,
        ),
        ('Lớp đã mở', vm.openClasses, false),
      ],
    };

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final stats = _statsFor(user.role, vm);
    final showNext =
        user.role == UserRole.student || user.role == UserRole.lecturer;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _Greeting(user: user, today: vm.today),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, s) in stats.indexed) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(
                              child: StatTile(
                                value: vm.loaded ? '${s.$2}' : '–',
                                label: s.$1,
                                highlight: vm.loaded && s.$3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showNext && vm.loaded) ...[
                      const SizedBox(height: 12),
                      _NextSession(
                        session: vm.nextSession,
                        today: vm.today,
                        onTap: () => _open(
                          context,
                          vm,
                          (_) => TimetableScreen(user: user),
                        ),
                      ),
                    ],
                    for (final (title, items) in _menuFor(user, vm)) ...[
                      SectionLabel(title),
                      _MenuGroup(
                        items: items,
                        onOpen: (page) => _open(context, vm, page),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mở một màn hình rồi tải lại số liệu: việc vừa làm có thể đổi huy hiệu.
  Future<void> _open(
    BuildContext context,
    HomeViewModel vm,
    WidgetBuilder page,
  ) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: page));
    await vm.load();
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user, required this.today});

  final AppUser user;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return HeroHeader(
      underStatusBar: true,
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateLabel(today).toUpperCase(),
              style: text.labelMedium?.copyWith(
                color: fptOrange,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Xin chào,',
              style: text.titleMedium?.copyWith(color: Colors.white70),
            ),
            Text(
              user.fullName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(user.role.label),
                _Pill(user.code),
                if (user.department.isNotEmpty)
                  _Pill('Bộ môn ${user.department}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(tagRadius),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Thẻ cam nổi bật: buổi học / buổi dạy sắp tới gần nhất. Chạm để mở lịch.
class _NextSession extends StatelessWidget {
  const _NextSession({
    required this.session,
    required this.today,
    required this.onTap,
  });

  final ClassSession? session;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = session;
    if (s == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('Không có buổi nào sắp tới'),
        ),
      );
    }
    final days = s.date.difference(today).inDays;
    final when = days == 0
        ? 'Hôm nay'
        : days == 1
        ? 'Ngày mai'
        : _dateLabel(s.date);
    final onPrimary = TextStyle(color: scheme.onPrimary);
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(appRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BUỔI TIẾP THEO · ${when.toUpperCase()}',
                style: text.labelMedium?.merge(onPrimary).copyWith(
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${s.subjectCode} - ${s.classCode}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleLarge?.merge(onPrimary).copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${s.slotTime} · Phòng ${s.room} · Buổi ${s.sessionNo}',
                style: text.bodyMedium?.merge(onPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một nhóm chức năng: các dòng trong cùng một thẻ, ngăn bằng đường kẻ mảnh.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items, required this.onOpen});

  final List<_MenuItem> items;
  final void Function(WidgetBuilder page) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const Divider(indent: 72),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: scheme.primary, size: 22),
              ),
              title: Text(
                item.label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(item.hint),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.badge > 0) ...[
                    Badge(label: Text('${item.badge}')),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => onOpen(item.page),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Cá nhân

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            underStatusBar: true,
            child: ContentWidth(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: fptOrange,
                    foregroundColor: Colors.white,
                    child: Text(
                      user.fullName.split(' ').last[0],
                      style: text.headlineSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(color: Colors.white),
                        ),
                        Text(
                          user.role.label,
                          style: text.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ContentWidth(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Đăng xuất'),
                      onPressed: () async {
                        await context.read<AuthViewModel>().signOut();
                        if (!context.mounted) return;
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil(Routes.login, (_) => false);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
