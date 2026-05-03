import 'package:flutter/material.dart';

import '../data/changelog.dart';
import '../theme.dart';
import '../utils/nav_back.dart';
import '../widgets/common.dart';

/// 설정 → 업데이트 소식. 정적 changelog를 카드 리스트로 보여줌.
/// 화면 진입 시 가장 최신 id를 SharedPreferences에 저장 → 빨간점 사라짐.
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  @override
  void initState() {
    super.initState();
    // 진입 즉시 "본 적 있음"으로 표시.
    markChangelogSeen();
  }

  String _prettyDate(String yyyymmdd) {
    if (yyyymmdd.length != 10) return yyyymmdd;
    return '${yyyymmdd.substring(0, 4)}.${yyyymmdd.substring(5, 7)}.${yyyymmdd.substring(8, 10)}';
  }

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
          '업데이트 소식',
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
            for (var i = 0; i < changelog.length; i++) ...[
              _entryCard(changelog[i], isLatest: i == 0),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                '여기까지가 마지막 소식이에요',
                style:
                    TextStyle(fontSize: 12, color: AppColors.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryCard(ChangelogEntry e, {required bool isLatest}) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _prettyDate(e.date),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.text3,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (isLatest) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryWeak,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryStrong,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            e.title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in e.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.text3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
