import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../state/selected_month.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/ko_date_picker.dart';
import '../widgets/skeleton.dart';
import '../widgets/tx_row.dart';
import 'shell_screen.dart' show ShellTabSignals;
import 'tx_modal.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    this.initialMonth,
    this.initialMajor,
    this.initialSub,
    this.initialQ,
    this.initialFixed,
  });

  final String? initialMonth;
  final String? initialMajor;
  final String? initialSub;
  final String? initialQ;
  final String? initialFixed; // '', 'true', 'false'

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _TxSort {
  dateDesc('날짜 (최신순)'),
  dateAsc('날짜 (오래된순)'),
  amountDesc('금액 (높은순)'),
  amountAsc('금액 (낮은순)');

  const _TxSort(this.label);
  final String label;
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _major = '';
  String _sub = '';
  String _q = '';
  String _fixed = ''; // '', 'true', 'false'

  String get _month => SelectedMonth.value.value;
  int? _minAmount;
  int? _maxAmount;
  _TxSort _sort = _TxSort.dateDesc;

  CategoriesData? _cats;
  Suggestions? _suggestions;
  PendingFixed? _pending;
  Set<String> _recurringKeys = const {};
  List<Tx>? _txs;
  Object? _txError;

  Timer? _qDebounce;
  late final TextEditingController _qCtrl;

  late final Listenable _apiListenable = Listenable.merge([
    Api.instance.txVersion,
    Api.instance.majorsVersion,
    Api.instance.categoriesVersion,
    Api.instance.fixedVersion,
  ]);
  bool _reloadScheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMonth != null && widget.initialMonth!.isNotEmpty) {
      SelectedMonth.value.value = widget.initialMonth!;
    }
    _major = widget.initialMajor ?? '';
    _sub = widget.initialSub ?? '';
    _q = widget.initialQ ?? '';
    _fixed = widget.initialFixed ?? '';
    _qCtrl = TextEditingController(text: _q);
    _apiListenable.addListener(_onApiChanged);
    SelectedMonth.value.addListener(_onMonthChanged);
    ShellTabSignals.transactionsTab.addListener(_onTabPressed);
    _bootstrap();
  }

  void _onMonthChanged() {
    if (mounted) {
      setState(() {});
      _reload();
    }
  }

  void _onTabPressed() {
    // 탭 버튼 클릭으로 들어왔을 때 — 필터가 있으면 초기화. (필터 없으면
    // reload 안 일으킴 — 불필요한 fetch 방지)
    // (대시보드 카드 클릭으로 들어오는 흐름은 didUpdateWidget이 따로
    // 처리하니 영향 X)
    if (!mounted) return;
    if (_hasFilter) _clearFilters();
  }

  bool get _hasFilter =>
      _major.isNotEmpty ||
      _sub.isNotEmpty ||
      _q.isNotEmpty ||
      _fixed.isNotEmpty ||
      _minAmount != null ||
      _maxAmount != null ||
      _sort != _TxSort.dateDesc;

  @override
  void didUpdateWidget(TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 대시보드 등 다른 화면에서 쿼리 파라미터를 바꿔 들어오면
    // StatefulShellRoute가 같은 State를 유지하므로 여기서 동기화한다.
    final changed = widget.initialMonth != oldWidget.initialMonth ||
        widget.initialMajor != oldWidget.initialMajor ||
        widget.initialSub != oldWidget.initialSub ||
        widget.initialQ != oldWidget.initialQ ||
        widget.initialFixed != oldWidget.initialFixed;
    if (!changed) return;
    if (widget.initialMonth != null && widget.initialMonth!.isNotEmpty) {
      SelectedMonth.value.value = widget.initialMonth!;
    }
    setState(() {
      _major = widget.initialMajor ?? '';
      _sub = widget.initialSub ?? '';
      _q = widget.initialQ ?? '';
      _fixed = widget.initialFixed ?? '';
      _qCtrl.text = _q;
    });
    _qDebounce?.cancel();
    _reload();
  }

  @override
  void dispose() {
    _apiListenable.removeListener(_onApiChanged);
    SelectedMonth.value.removeListener(_onMonthChanged);
    ShellTabSignals.transactionsTab.removeListener(_onTabPressed);
    _qDebounce?.cancel();
    _qCtrl.dispose();
    super.dispose();
  }

  void _onApiChanged() {
    if (_reloadScheduled || !mounted) return;
    _reloadScheduled = true;
    scheduleMicrotask(() {
      _reloadScheduled = false;
      if (mounted) _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    try {
      final cats = await Api.instance.listCategories();
      Suggestions? sug;
      try {
        sug = await Api.instance.getSuggestions();
      } catch (_) {
        sug = const Suggestions(merchants: [], cards: []);
      }
      Set<String> recurring = const {};
      try {
        final list = await Api.instance.listFixedExpenses();
        recurring = {
          for (final f in list)
            if (f.active) '${f.name}|${f.major}',
        };
      } catch (_) {/* 무시 */}
      if (!mounted) return;
      setState(() {
        _cats = cats;
        _suggestions = sug;
        _recurringKeys = recurring;
      });
      _reload();
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e), error: true);
    }
  }

  Future<void> _reload() async {
    _refreshPending();
    try {
      final txs = await Api.instance.listTransactions(
        month: _month,
        major: _major.isEmpty ? null : _major,
        sub: _sub.isEmpty ? null : _sub,
        q: _q.isEmpty ? null : _q,
        fixed: _fixed == 'true'
            ? true
            : _fixed == 'false'
                ? false
                : null,
      );
      if (!mounted) return;
      setState(() {
        _txs = txs;
        _txError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _txError = e);
    }
  }

  Future<void> _refreshPending() async {
    try {
      final p = await Api.instance.getPendingFixedExpenses(_month);
      if (!mounted) return;
      setState(() => _pending = p);
    } catch (_) {/* 무시 */}
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

  void _onQChanged(String v) {
    _qDebounce?.cancel();
    _qDebounce = Timer(const Duration(milliseconds: 250), () {
      _q = v;
      _reload();
    });
  }

  Future<void> _openModal([Tx? tx]) async {
    if (_cats == null) return;
    final result = await showTxModal(
      context,
      cats: _cats!,
      suggestions: _suggestions ?? const Suggestions(merchants: [], cards: []),
      tx: tx,
    );
    if (result == TxModalResult.changed && mounted) {
      _suggestions = null;
      // 자동완성 재로드 (백그라운드)
      Api.instance.getSuggestions().then((s) {
        if (mounted) setState(() => _suggestions = s);
      }).catchError((_) {});
      _reload();
    }
  }

  Future<void> _applyFixed() async {
    try {
      final r = await Api.instance.applyFixedExpenses(_month);
      if (!mounted) return;
      showToast(
        context,
        '${r.insertedCount}건 등록'
        '${r.skippedCount > 0 ? ' · ${r.skippedCount}건 스킵' : ''}',
      );
      _reload();
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e), error: true);
    }
  }

  String _headerSub() {
    final parts = <String>[];
    if (_major.isNotEmpty) parts.add(_major);
    if (_sub.isNotEmpty) parts.add(_sub);
    if (_fixed == 'true') parts.add('고정비');
    if (_fixed == 'false') parts.add('변동비');
    return parts.isEmpty
        ? '${ymLabel(_month)} 지출'
        : '${ymLabel(_month)} · ${parts.join(' · ')}';
  }

  void _clearFilters() {
    setState(() {
      _major = '';
      _sub = '';
      _q = '';
      _fixed = '';
      _minAmount = null;
      _maxAmount = null;
      _sort = _TxSort.dateDesc;
      _qCtrl.text = '';
    });
    _reload();
  }

  /// 서버에서 받은 거래에 client-side 추가 필터(금액 범위) + 정렬 적용.
  List<Tx> _applyExtraFilters(List<Tx> rows) {
    var filtered = rows;
    if (_minAmount != null) {
      filtered = filtered.where((t) => t.amount >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      filtered = filtered.where((t) => t.amount <= _maxAmount!).toList();
    }
    final sorted = [...filtered];
    switch (_sort) {
      case _TxSort.dateDesc:
        sorted.sort((a, b) {
          final c = b.date.compareTo(a.date);
          return c != 0 ? c : b.id.compareTo(a.id);
        });
        break;
      case _TxSort.dateAsc:
        sorted.sort((a, b) {
          final c = a.date.compareTo(b.date);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
        break;
      case _TxSort.amountDesc:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _TxSort.amountAsc:
        sorted.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    return sorted;
  }

  String _amountRangeLabel() {
    if (_minAmount != null && _maxAmount != null) {
      return '${won(_minAmount!)} ~ ${won(_maxAmount!)}원';
    }
    if (_minAmount != null) return '${won(_minAmount!)}원 이상';
    if (_maxAmount != null) return '${won(_maxAmount!)}원 이하';
    return '';
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _FilterSheet(
        initialMin: _minAmount,
        initialMax: _maxAmount,
        initialSort: _sort,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _minAmount = result.minAmount;
      _maxAmount = result.maxAmount;
      _sort = result.sort;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cats = _cats;
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openModal(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('거래 추가'),
      ),
      body: SafeArea(
        child: cats == null
            ? _txSkeleton()
            : RefreshIndicator(
                onRefresh: () async {
                  Api.instance.invalidateAllCaches();
                  await _reload();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
                  children: [
                    PageHeader(
                      title: '거래내역',
                      subtitle: _headerSub(),
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _toolbar(cats),
                    ),
                    if (_sub.isNotEmpty ||
                        _q.isNotEmpty ||
                        _minAmount != null ||
                        _maxAmount != null ||
                        _sort != _TxSort.dateDesc)
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (_sub.isNotEmpty)
                              _Chip(
                                label: '세부: $_sub',
                                onClear: _clearFilters,
                              ),
                            if (_q.isNotEmpty)
                              _Chip(
                                label: '검색: $_q',
                                onClear: _clearFilters,
                              ),
                            if (_minAmount != null || _maxAmount != null)
                              _Chip(
                                label: _amountRangeLabel(),
                                onClear: () {
                                  setState(() {
                                    _minAmount = null;
                                    _maxAmount = null;
                                  });
                                },
                              ),
                            if (_sort != _TxSort.dateDesc)
                              _Chip(
                                label: '정렬: ${_sort.label}',
                                onClear: () =>
                                    setState(() => _sort = _TxSort.dateDesc),
                              ),
                          ],
                        ),
                      ),
                    _list(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _txSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
      children: [
        const PageHeader(title: '거래내역', subtitle: ''),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: const [
              Skeleton(height: 44, radius: 10),
              SizedBox(height: 8),
              Row(children: [
                Expanded(child: Skeleton(height: 44, radius: 10)),
                SizedBox(width: 8),
                Skeleton(width: 130, height: 44, radius: 10),
                SizedBox(width: 6),
                Skeleton(width: 40, height: 40, radius: 10),
              ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _txListSkeleton(),
        ),
      ],
    );
  }

  Widget _txListSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonLine(width: 90, height: 11),
              SizedBox(height: 8),
              SkeletonLine(width: 160, height: 24),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          tight: true,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            children: [
              for (var i = 0; i < 5; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: const [
                      Skeleton(
                          width: 36, height: 36, shape: BoxShape.circle),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(width: 110),
                            SizedBox(height: 6),
                            SkeletonLine(width: 60, height: 10),
                          ],
                        ),
                      ),
                      SkeletonLine(width: 70, height: 14),
                    ],
                  ),
                ),
                if (i < 4) const Divider(color: AppColors.line2, height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolbar(CategoriesData cats) {
    final majors = ['', ...cats.majors];
    return Column(
      children: [
        TextField(
          controller: _qCtrl,
          onChanged: _onQChanged,
          decoration: const InputDecoration(
            hintText: '가맹점/메모 검색',
            prefixIcon: Icon(Icons.search,
                color: AppColors.text3, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppDropdown<String>(
                value: _major,
                items: [
                  for (final m in majors)
                    AppDropdownItem(
                      value: m,
                      label: m.isEmpty ? '전체 카테고리' : m,
                    ),
                ],
                onChanged: (v) {
                  setState(() {
                    _major = v;
                    _sub = '';
                  });
                  _reload();
                },
              ),
            ),
            const SizedBox(width: 8),
            _SegBtn(
              options: const [
                _SegOpt('', '전체'),
                _SegOpt('true', '고정'),
                _SegOpt('false', '변동'),
              ],
              value: _fixed,
              onChanged: (v) {
                setState(() => _fixed = v);
                _reload();
              },
            ),
            const SizedBox(width: 6),
            _FilterIconBtn(
              active: _minAmount != null ||
                  _maxAmount != null ||
                  _sort != _TxSort.dateDesc,
              onTap: _openFilterSheet,
            ),
          ],
        ),
      ],
    );
  }

  Widget _list() {
    if (_txs == null) {
      if (_txError != null) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text(errorMessage(_txError!),
              style: const TextStyle(color: AppColors.danger)),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _txListSkeleton(),
      );
    }
    final rows = _applyExtraFilters(_txs!);
    final hasFilter = _hasFilter;
    final total = rows.fold<int>(0, (s, r) => s + r.amount);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Summary(
            label: hasFilter
                ? '필터된 합계 · ${ymLabel(_month)}'
                : '${ymLabel(_month)} 합계',
            total: total,
            count: rows.length,
            filtered: hasFilter,
          ),
          if (_pending != null && _pending!.pending > 0) ...[
            const SizedBox(height: 10),
            _PendingFixedBanner(
              month: _month,
              pendingCount: _pending!.pending,
              onApply: _applyFixed,
            ),
          ],
          const SizedBox(height: 10),
          if (rows.isEmpty)
            EmptyCard(
              icon: hasFilter
                  ? Icons.filter_alt_off_outlined
                  : Icons.receipt_long_outlined,
              title: hasFilter
                  ? '조건에 맞는 거래가 없어요'
                  : '이번 달에 등록된 거래가 없어요',
              body: '오른쪽 아래 + 추가 버튼으로 거래를 등록할 수 있어요.',
            )
          else
            AppCard(
              tight: true,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              child: _grouped(rows),
            ),
        ],
      ),
    );
  }

  Widget _grouped(List<Tx> rows) {
    final byDate = <String, List<Tx>>{};
    for (final r in rows) {
      byDate.putIfAbsent(r.date, () => []).add(r);
    }
    final children = <Widget>[];
    final entries = byDate.entries.toList();
    for (final e in entries) {
      final sum = e.value.fold<int>(0, (s, t) => s + t.amount);
      children.add(TxDayHeader(date: e.key, total: sum));
      for (final tx in e.value) {
        final key = '${tx.merchant}|${tx.majorCategory}';
        children.add(TxRow(
          tx: tx,
          isRecurring: _recurringKeys.contains(key),
          onTap: () => _openModal(tx),
        ));
      }
    }
    return Column(children: children);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.total,
    required this.count,
    required this.filtered,
  });
  final String label;
  final int total;
  final int count;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filtered ? AppColors.primary : AppColors.text3,
              )),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(won(total),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    letterSpacing: -0.02,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
              const SizedBox(width: 4),
              const Text('원',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.text3,
                    fontWeight: FontWeight.w600,
                  )),
              const Spacer(),
              Text('$count건',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.text3,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingFixedBanner extends StatelessWidget {
  const _PendingFixedBanner({
    required this.month,
    required this.pendingCount,
    required this.onApply,
  });
  final String month;
  final int pendingCount;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.primaryWeak,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13.5,
                ),
                children: [
                  TextSpan(
                      text: '${ymLabel(month)} 정기지출 $pendingCount건',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: '이 아직 등록되지 않았어요'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
            onPressed: onApply,
            child: const Text('일괄 등록'),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onClear,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.text2,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            const Icon(Icons.close, size: 14, color: AppColors.text3),
          ],
        ),
      ),
    );
  }
}

class _SegOpt {
  final String value;
  final String label;
  const _SegOpt(this.value, this.label);
}

class _FilterIconBtn extends StatelessWidget {
  const _FilterIconBtn({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primaryWeak : AppColors.surface2,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            Icons.tune,
            size: 18,
            color: active ? AppColors.primary : AppColors.text2,
          ),
        ),
      ),
    );
  }
}

class _FilterResult {
  final int? minAmount;
  final int? maxAmount;
  final _TxSort sort;
  const _FilterResult({
    required this.minAmount,
    required this.maxAmount,
    required this.sort,
  });
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initialMin,
    required this.initialMax,
    required this.initialSort,
  });
  final int? initialMin;
  final int? initialMax;
  final _TxSort initialSort;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late _TxSort _sort;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController();
    _maxCtrl = TextEditingController();
    if (widget.initialMin != null) {
      AmountField.setNumber(_minCtrl, widget.initialMin);
    }
    if (widget.initialMax != null) {
      AmountField.setNumber(_maxCtrl, widget.initialMax);
    }
    _sort = widget.initialSort;
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.of(context).pop(_FilterResult(
      minAmount: AmountField.parse(_minCtrl),
      maxAmount: AmountField.parse(_maxCtrl),
      sort: _sort,
    ));
  }

  void _reset() {
    setState(() {
      _minCtrl.clear();
      _maxCtrl.clear();
      _sort = _TxSort.dateDesc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  const Text('필터·정렬',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('초기화',
                        style: TextStyle(
                            color: AppColors.text3, fontSize: 13)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('금액 범위',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AmountField(
                            controller: _minCtrl,
                            label: '최소',
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('~',
                              style: TextStyle(
                                  fontSize: 16, color: AppColors.text3)),
                        ),
                        Expanded(
                          child: AmountField(
                            controller: _maxCtrl,
                            label: '최대',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('정렬',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text2)),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        for (final s in _TxSort.values)
                          InkWell(
                            onTap: () => setState(() => _sort = s),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    _sort == s
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 18,
                                    color: _sort == s
                                        ? AppColors.primary
                                        : AppColors.text4,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(s.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _sort == s
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: _sort == s
                                            ? AppColors.text
                                            : AppColors.text2,
                                      )),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 12 + mq.padding.bottom * 0.4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line2)),
              ),
              child: FilledButton(
                onPressed: _apply,
                child: const Text('적용'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final List<_SegOpt> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o.value),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: value == o.value
                      ? AppColors.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                  boxShadow: value == o.value
                      ? const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, 1)),
                        ]
                      : null,
                ),
                child: Text(o.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: value == o.value
                          ? AppColors.text
                          : AppColors.text3,
                    )),
              ),
            ),
        ],
      ),
    );
  }
}
