import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  _BudgetsData? _data;
  Object? _error;
  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final api = Api.instance;
      final results = await Future.wait([
        api.listBudgets(),
        api.getDashboard(todayYm()),
      ]);
      final budgets = results[0] as List<Budget>;
      final dash = results[1] as Dashboard;
      final variable = {
        for (final c in dash.categories) c.major: c.variableSpent,
      };

      // 컨트롤러 동기화 (재로드 시 새 값으로 교체)
      final keep = <String>{};
      for (final b in budgets) {
        keep.add(b.major);
        _ctrls.putIfAbsent(
            b.major, () => TextEditingController());
        AmountField.setNumber(_ctrls[b.major]!, b.monthlyAmount);
      }
      final toRemove =
          _ctrls.keys.where((k) => !keep.contains(k)).toList();
      for (final k in toRemove) {
        _ctrls.remove(k)?.dispose();
      }
      if (!mounted) return;
      setState(() {
        _data = _BudgetsData(budgets: budgets, variable: variable);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    if (_saving || _data == null) return;
    setState(() => _saving = true);
    try {
      final updated = <Budget>[];
      for (final b in _data!.budgets) {
        final amt = AmountField.parse(_ctrls[b.major]!) ?? 0;
        updated.add(Budget(major: b.major, monthlyAmount: amt));
      }
      await Api.instance.saveBudgets(updated);
      if (!mounted) return;
      showToast(context, '예산을 저장했어요');
      await _reload();
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_saving || _data == null) ? null : _save,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.check),
        label: Text(_saving ? '저장 중...' : '저장'),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_data == null) {
              if (_error != null) {
                return Center(child: Text(errorMessage(_error!)));
              }
              return const Center(child: CircularProgressIndicator());
            }
            final d = _data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
              children: [
                const PageHeader(
                  title: '예산 설정',
                  subtitle: '고정비는 예산에서 제외돼요.',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final b in d.budgets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BudgetEditCard(
                            major: b.major,
                            spent: d.variable[b.major] ?? 0,
                            budget: b.monthlyAmount,
                            controller: _ctrls[b.major]!,
                          ),
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

class _BudgetEditCard extends StatelessWidget {
  const _BudgetEditCard({
    required this.major,
    required this.spent,
    required this.budget,
    required this.controller,
  });
  final String major;
  final int spent;
  final int budget;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 999.0) : 0.0;
    final pctClamped = pct > 1.0 ? 1.0 : pct;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(major,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ),
              Text('${(pct * 100).round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pct >= 1.0
                        ? AppColors.danger
                        : pct >= 0.8
                            ? AppColors.warning
                            : AppColors.text2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13.5),
              children: [
                TextSpan(
                    text: '${won(spent)}원',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    )),
                const TextSpan(
                    text: ' 사용',
                    style: TextStyle(color: AppColors.text2)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ProgressTrack(percent: pctClamped),
          const SizedBox(height: 14),
          AmountField(
              controller: controller, label: '이번 달 예산 (원)'),
        ],
      ),
    );
  }
}

class _BudgetsData {
  final List<Budget> budgets;
  final Map<String, int> variable;
  const _BudgetsData({
    required this.budgets,
    required this.variable,
  });
}
