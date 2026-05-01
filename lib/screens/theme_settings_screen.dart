import 'package:flutter/material.dart';

import '../auth.dart';
import '../theme.dart';
import '../utils/nav_back.dart';
import '../widgets/common.dart';

/// 테마 모드 선택 — 시스템 / 라이트 / 다크.
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold/AppBar의 AppColors.* 도 mode 변경 시 즉시 반영되게 전체를
    // ValueListenableBuilder로 감쌈 (이 화면은 sub route라 main의 MaterialApp
    // 재mount 사이클로는 안에 있는 화면이라 즉시 반영 안 되는 케이스가 있음).
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AuthService.themeMode,
      builder: (context, current, _) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.text2),
              onPressed: () => goBackOr(context, '/settings'),
            ),
            title: Text(
              '테마',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            centerTitle: false,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                AppCard(
                  tight: true,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ThemeOption(
                        icon: Icons.brightness_auto,
                        title: '시스템 설정 따라가기',
                        subtitle: '폰/PC 설정에 맞춰 자동',
                        selected: current == ThemeMode.system,
                        isFirst: true,
                        onTap: () =>
                            AuthService.setThemeMode(ThemeMode.system),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 1, color: AppColors.line2),
                      ),
                      _ThemeOption(
                        icon: Icons.light_mode_outlined,
                        title: '라이트',
                        subtitle: '흰 배경',
                        selected: current == ThemeMode.light,
                        onTap: () =>
                            AuthService.setThemeMode(ThemeMode.light),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 1, color: AppColors.line2),
                      ),
                      _ThemeOption(
                        icon: Icons.dark_mode_outlined,
                        title: '다크',
                        subtitle: '검은 배경',
                        selected: current == ThemeMode.dark,
                        isLast: true,
                        onTap: () =>
                            AuthService.setThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(AppRadius.xl);
    final radius = BorderRadius.only(
      topLeft: isFirst ? r : Radius.zero,
      topRight: isFirst ? r : Radius.zero,
      bottomLeft: isLast ? r : Radius.zero,
      bottomRight: isLast ? r : Radius.zero,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryWeak,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 22, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
