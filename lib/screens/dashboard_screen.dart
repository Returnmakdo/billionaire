import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../auth.dart';
import '../state/selected_month.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/ko_date_picker.dart';
import '../widgets/kpi_card.dart';
import '../widgets/merchant_item.dart';
import '../widgets/skeleton.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _DashData? _data;
  Object? _error;

  String get _month => SelectedMonth.value.value;

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
    SelectedMonth.value.addListener(_onMonthChanged);
    AuthService.userVersion.addListener(_onUserChanged);
    _reload();
  }

  @override
  void dispose() {
    _apiListenable.removeListener(_onApiChanged);
    SelectedMonth.value.removeListener(_onMonthChanged);
    AuthService.userVersion.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onMonthChanged() {
    if (mounted) {
      setState(() {});
      _reload();
    }
  }

  void _onUserChanged() {
    // 닉네임 변경 등 사용자 정보 갱신 시 인사말 즉시 반영.
    if (mounted) setState(() {});
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
    SelectedMonth.value.value = shiftYm(_month, delta);
  }

  Future<void> _pickMonth() async {
    final picked = await showKoMonthPicker(
      context: context,
      initialYm: _month,
    );
    if (picked != null && picked != _month) {
      SelectedMonth.value.value = picked;
    }
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
            return _dashboardSkeleton();
          }
          final d = _data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
            children: [
              PageHeader(
                title: '${AuthService.displayName()}님 어서오세요',
                subtitle: '한눈에 보는 이번 달 지출',
                actions: [
                  MonthSwitcher(
                    label: MediaQuery.sizeOf(context).width >= 700
                        ? ymLabel(_month)
                        : ymLabelShort(_month),
                    onPrev: () => _shift(-1),
                    onNext: () => _shift(1),
                    onTapLabel: _pickMonth,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _kpiGrid(d.data),
              ),
              const SizedBox(height: 18),
              _section(
                title: '카테고리 비율',
                child: AppCard(
                  child: CategoryShare(
                    categories: d.data.categories,
                    month: _month,
                  ),
                ),
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

  Widget _dashboardSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
      children: [
        const PageHeader(title: '...', subtitle: ''),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 700;
              if (wide) {
                return Row(
                  children: const [
                    Expanded(child: SkeletonCard(height: 110)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonCard(height: 110)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonCard(height: 110)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonCard(height: 110)),
                  ],
                );
              }
              return Column(
                children: const [
                  Row(children: [
                    Expanded(child: SkeletonCard(height: 110)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonCard(height: 110)),
                  ]),
                  SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: SkeletonCard(height: 110)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonCard(height: 110)),
                  ]),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    SkeletonLine(width: 120, height: 22),
                    Spacer(),
                    Skeleton(width: 130, height: 32, radius: 8),
                  ],
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < 4; i++) ...[
                  Row(
                    children: const [
                      Skeleton(
                          width: 10, height: 10, shape: BoxShape.circle),
                      SizedBox(width: 10),
                      Expanded(child: SkeletonLine(width: 80)),
                      SizedBox(width: 10),
                      SkeletonLine(width: 60, height: 13),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      SizedBox(width: 20),
                      Expanded(child: Skeleton(height: 4, radius: 99)),
                      SizedBox(width: 8),
                      SkeletonLine(width: 28, height: 11),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ],
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

  Widget _subList(List<SubCategoryStat> rows) {
    if (rows.isEmpty) {
      return EmptyCard(
        icon: Icons.receipt_long_outlined,
        title: '이번 달 거래가 없어요',
        body: '거래를 추가하면 패턴을 짚어드릴게요.',
        actionLabel: '거래 추가',
        onAction: () => context.go('/transactions'),
      );
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
      return EmptyCard(
        icon: Icons.show_chart,
        title: '아직 거래가 없어요',
        body: '거래를 추가하면 6개월 추이가 보여요.',
        actionLabel: '거래 추가',
        onAction: () => context.go('/transactions'),
      );
    }
    return AppCard(
      child: MonthlyTrendBar(
        trend: d.trend,
        currentMonth: d.month,
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
