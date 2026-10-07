import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';
import '../team/team_screen.dart';
import '../todo_list/todo_list_screen.dart';

/// 하단 탭 4개(할 일·일정·팀·설정)를 담는 앱의 첫 화면.
///
/// 탭을 옮겨도 각 탭의 스크롤·입력 상태가 유지되도록 [IndexedStack]으로 모두 붙잡아 둔다.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _tabs = [
    _Tab(label: '할 일', icon: Icons.checklist, screen: TodoListScreen()),
    _Tab(
      label: '일정',
      icon: Icons.calendar_today_outlined,
      screen: CalendarScreen(),
    ),
    _Tab(label: '팀', icon: Icons.group_outlined, screen: TeamScreen()),
    _Tab(label: '설정', icon: Icons.settings_outlined, screen: SettingsScreen()),
  ];

  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        // 스낵바는 바깥 Scaffold에만 뜨면 탭 화면의 FAB가 비켜 주지 않아 버튼을 가린다.
        // 탭마다 따로 두면 그 탭의 Scaffold에 떠서 FAB 위로 올라간다.
        children: [
          for (final tab in _tabs) ScaffoldMessenger(child: tab.screen),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: NavigationBar(
          height: _navigationBarHeight,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ],
        ),
      ),
    );
  }

  static const _navigationBarHeight = AppSize.fab + AppSpacing.xs;
}

class _Tab {
  const _Tab({required this.label, required this.icon, required this.screen});

  final String label;
  final IconData icon;
  final Widget screen;
}
