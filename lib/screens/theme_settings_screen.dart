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
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: AuthService.themeMode,
          builder: (context, current, _) {
            return ListView(
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
                        onTap: () =>
                            AuthService.setThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
