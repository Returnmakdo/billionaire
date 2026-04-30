import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/budget_card.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/kpi_card.dart';
import '../widgets/merchant_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _month = todayYm();
  _DashData? _data;
  Object? _error;

  late final Listenable _apiListenable = Listenable.merge([
    Api.instance.txVersion,
    Api.instance.majorsVersion,
    Api.instance.budgetsVersion,
  ]);
  bool _reloadScheduled = false;

  @override
  void initState() {
    super.initState();
    _apiListenable.addListener(_onApiChanged);
    _reload();
  }

  @override
  void dispose() {
    _apiListenable.removeListener(_onApiChanged);
    super.dispose();
  }

  void _onApiChanged() {
    if (_reloadScheduled || !mounted) return;
    _reloadScheduled = true;
    scheduleMicrotask(() {
      _reloadScheduled = false;
      if (mounted) _reload();
    });
  }

  Future<void> _reload() async {
    try {
      final api = Api.instance;
      final results = await Future.wait([
        api.getDashboard(_month),
        api.getSubCategoryStats(month: _month, limit: 10, fixed: false),
      ]);
      if (!mounted) return;
      setState(() {
        _data = _DashData(
          data: results[0] as Dashboard,
          subs: results[1] as List<SubCategoryStat>,
        );
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _shift(int delta) {
    setState(() => _month = shiftYm(_month, delta));
    _reload();
  }

  Future<void> _refresh() async {
    Api.instance.invalidateAllCaches();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Builder(
        builder: (context) {
          if (_data == null) {
            if (_error != null) {
              return ListView(children: [
                const SizedBox(height: 80),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(errorMessage(_error!),
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                ),
              ]);
            }
            return ListView(
              children: const [
                SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          final d = _data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
            children: [
              PageHeader(
                title: '대시보드',
                subtitle: '한눈에 보는 이번 달 지출',
                actions: [
                  MonthSwitcher(
                    label: ymLabel(_month),
                    onPrev: () => _shift(-1),
                    onNext: () => _shift(1),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _kpiGrid(d.data),
              ),
              const SizedBox(height: 18),
              _section(
                title: '이번 달 예산',
                meta: '고정비 제외',
                child: _budgetGrid(d.data),
              ),
              _section(
                title: '태그 TOP 10',
                meta: '변동비만 · 이번 달 합계 기준',
                child: _subList(d.subs),
              ),
              _section(
                title: '최근 6개월',
                child: _trend(d.data),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section({
    required String title,
    String? meta,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: title, meta: meta),
          child,
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _kpiGrid(Dashboard d) {
    final delta = d.thisMonthTotal - d.prevMonthTotal;
    final pct = d.prevMonthTotal > 0
        ? (delta / d.prevMonthTotal * 100).round()
        : null;
    final deltaText = d.prevMonthTotal == 0
        ? '전달 데이터 없음'
        : '전달 대비 ${delta >= 0 ? '+' : ''}${smartWon(delta)}원'
            '${pct != null ? ' (${pct >= 0 ? '+' : ''}$pct%)' : ''}';
    final fixedText =
        '고정 ${smartWon(d.fixedTotal)}원 · 변동 ${smartWon(d.variableTotal)}원';

    final cards = [
      KpiCard(
        label: '이번 달 지출',
        value: smartWon(d.thisMonthTotal),
        primary: true,
        delta: deltaText,
        deltaExtra: fixedText,
      ),
      KpiCard(
        label: '지난달',
        value: smartWon(d.prevMonthTotal),
        delta: ymLabel(shiftYm(d.month, -1)),
      ),
      KpiCard(
        label: '일평균',
        value: smartWon(d.dailyAvg),
        delta: '이번 달 누적 기준',
      ),
      KpiCard(
        label: '연 누적',
        value: smartWon(d.yearTotal),
        delta: '${d.year}년 거래 합계',
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 700;
      if (wide) {
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: cards[i]),
            ],
          ],
        );
      }
      // 2x2
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    });
  }

  Widget _budgetGrid(Dashboard d) {
    final sorted = [...d.categories]
      ..sort((a, b) => b.variableSpent.compareTo(a.variableSpent));
    return LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth >= 700;
      if (two) {
        final widgets = <Widget>[];
        for (var i = 0; i < sorted.length; i += 2) {
          final left = sorted[i];
          final right = i + 1 < sorted.length ? sorted[i + 1] : null;
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildBudgetCard(d.month, left)),
                const SizedBox(width: 10),
                Expanded(
                  child: right != null
                      ? _buildBudgetCard(d.month, right)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ));
        }
        return Column(children: widgets);
      }
      return Column(
        children: [
          for (final cat in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildBudgetCard(d.month, cat),
            ),
        ],
      );
    });
  }

  Widget _buildBudgetCard(String month, CategoryStats c) {
    return BudgetCard(
      major: c.major,
      spent: c.variableSpent,
      budget: c.budget,
      onTap: () => context.go(
        '/transactions?month=${Uri.encodeComponent(month)}'
        '&major=${Uri.encodeComponent(c.major)}',
      ),
    );
  }

  Widget _subList(List<SubCategoryStat> rows) {
    if (rows.isEmpty) {
      return const EmptyCard(title: '이번 달 거래가 없어요');
    }
    return AppCard(
      tight: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            MerchantItem(
              rank: i + 1,
              major: rows[i].major,
              title: rows[i].sub,
              subtitle: rows[i].major,
              amount: rows[i].total,
              count: rows[i].count,
              onTap: () => context.go(
                '/transactions'
                '?month=${Uri.encodeComponent(_month)}'
                '&major=${Uri.encodeComponent(rows[i].major)}'
                '&sub=${Uri.encodeComponent(rows[i].sub)}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _trend(Dashboard d) {
    if (d.trend.isEmpty) {
      return const EmptyCard(
        title: '아직 거래가 없어요',
        body: '거래내역에서 첫 거래를 추가해보세요.',
      );
    }
    final maxV = d.trend.fold<int>(1, (m, t) => t.total > m ? t.total : m);
    return AppCard(
      child: SizedBox(
        height: 190,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final t in d.trend)
                    Expanded(
                      child: _TrendBar(
                        total: t.total,
                        ratio: t.total / maxV,
                        isCurrent: t.ym == d.month,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final t in d.trend)
                  Expanded(
                    child: Center(
                      child: Text(
                        '${int.parse(t.ym.substring(5, 7))}월',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: t.ym == d.month
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: t.ym == d.month
                              ? AppColors.primary
                              : AppColors.text3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.total,
    required this.ratio,
    required this.isCurrent,
  });
  final int total;
  final double ratio;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final color = isCurrent ? AppColors.primary : AppColors.primaryWeak;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(wonShort(total),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.text3,
                fontFeatures: [FontFeature.tabularFigures()],
              )),
          const SizedBox(height: 4),
          FractionallySizedBox(
            widthFactor: 0.8,
            child: Container(
              height: ratio.clamp(0.04, 1.0) * 130,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashData {
  final Dashboard data;
  final List<SubCategoryStat> subs;
  const _DashData({
    required this.data,
    required this.subs,
  });
}
