import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.child});
  final Widget child;

  static const tabs = [
    _Tab('대시보드', '/dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _Tab('거래내역', '/transactions', Icons.receipt_long_outlined, Icons.receipt_long),
    _Tab('예산', '/budgets', Icons.savings_outlined, Icons.savings),
    _Tab('정기지출', '/fixed', Icons.repeat, Icons.repeat_on),
    _Tab('카테고리', '/categories', Icons.category_outlined, Icons.category),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final i = tabs.indexWhere((t) => loc.startsWith(t.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.primaryWeak,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(tabs[i].path),
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
  const _Tab(this.label, this.path, this.icon, this.activeIcon);
  final String label;
  final String path;
  final IconData icon;
  final IconData activeIcon;
}
