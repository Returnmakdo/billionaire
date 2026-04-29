import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const tabs = [
    _Tab('대시보드', Icons.dashboard_outlined, Icons.dashboard),
    _Tab('거래내역', Icons.receipt_long_outlined, Icons.receipt_long),
    _Tab('예산', Icons.savings_outlined, Icons.savings),
    _Tab('정기지출', Icons.repeat, Icons.repeat_on),
    _Tab('카테고리', Icons.category_outlined, Icons.category),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.primaryWeak,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon, color: AppColors.text3),
              selectedIcon: Icon(t.activeIcon, color: AppColors.primary),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
