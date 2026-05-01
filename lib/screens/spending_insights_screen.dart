import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../state/selected_month.dart';
import '../theme.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/ko_date_picker.dart';
import '../widgets/skeleton.dart';
import '../widgets/spending_insight_pages.dart';

class SpendingInsightsScreen extends StatefulWidget {
  const SpendingInsightsScreen({super.key});

  @override
  State<SpendingInsightsScreen> createState() => _SpendingInsightsScreenState();
}

class _SpendingInsightsScreenState extends State<SpendingInsightsScreen> {
  InsightVisualData? _data;
  Object? _error;

  String get _month => SelectedMonth.value.value;

  late final Listenable _apiListenable = Listenable.merge([
    Api.instance.txVersion,
    Api.instance.budgetsVersion,
  ]);
  bool _reloadScheduled = false;

  @override
  void initState() {
    super.initState();
    SelectedMonth.value.addListener(_onMonthChanged);
    _apiListenable.addListener(_onApiChanged);
    _reload();
  }

  @override
  void dispose() {
    SelectedMonth.value.removeListener(_onMonthChanged);
    _apiListenable.removeListener(_onApiChanged);
    super.dispose();
  }

  void _onMonthChanged() {
    if (mounted) {
      setState(() {});
      _reload();
    }
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
        api.listTransactions(month: _month),
        api.listBudgets(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = InsightVisualData(
          dashboard: results[0] as Dashboard,
          monthTxs: results[1] as List<Tx>,
          budgets: results[2] as List<Budget>,
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
      children: [
        PageHeader(
          title: '소비 패턴 분석',
          subtitle: '한 달 지출을 보고 코치가 짚어드려요',
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
          child: _body(),
        ),
      ],
    );
  }

  Widget _body() {
    if (_data == null) {
      if (_error != null) {
        return AppCard(
          child: Text(
            errorMessage(_error!),
            style: const TextStyle(color: AppColors.danger),
          ),
        );
      }
      return const AppCard(
        child: SkeletonCard(height: 380),
      );
    }
    return AiInsightCard(
      key: ValueKey('insights-$_month'),
      month: _month,
      data: _data,
    );
  }
}
