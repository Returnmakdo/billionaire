import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/tx_row.dart';
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

class _TransactionsScreenState extends State<TransactionsScreen> {
  late String _month;
  String _major = '';
  String _sub = '';
  String _q = '';
  String _fixed = ''; // '', 'true', 'false'

  CategoriesData? _cats;
  Suggestions? _suggestions;
  PendingFixed? _pending;
  Set<String> _recurringKeys = const {};
  List<Tx>? _txs;
  Object? _txError;

  Timer? _qDebounce;
  late final TextEditingController _qCtrl;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth ?? todayYm();
    _major = widget.initialMajor ?? '';
    _sub = widget.initialSub ?? '';
    _q = widget.initialQ ?? '';
    _fixed = widget.initialFixed ?? '';
    _qCtrl = TextEditingController(text: _q);
    _bootstrap();
  }

  @override
  void dispose() {
    _qDebounce?.cancel();
    _qCtrl.dispose();
    super.dispose();
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
    setState(() => _month = shiftYm(_month, delta));
    _reload();
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
      _qCtrl.text = '';
    });
    _reload();
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
            ? const Center(child: CircularProgressIndicator())
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
                          label: ymLabel(_month),
                          onPrev: () => _shift(-1),
                          onNext: () => _shift(1),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _toolbar(cats),
                    ),
                    if (_sub.isNotEmpty || _q.isNotEmpty)
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
              child: _CategoryPicker(
                value: _major,
                majors: majors,
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rows = _txs!;
    final hasFilter = _major.isNotEmpty ||
        _sub.isNotEmpty ||
        _q.isNotEmpty ||
        _fixed.isNotEmpty;
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

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.value,
    required this.majors,
    required this.onChanged,
  });
  final String value;
  final List<String> majors;
  final ValueChanged<String> onChanged;

  Future<void> _open(BuildContext context) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = context.findRenderObject() as RenderBox;
    final width = button.size.width;
    final topLeft = button.localToGlobal(
      Offset(0, button.size.height + 4),
      ancestor: overlay,
    );
    final bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );
    final result = await showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surface,
      constraints: BoxConstraints.tightFor(width: width),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      items: [
        for (final m in majors)
          PopupMenuItem(
            value: m,
            child: Text(m.isEmpty ? '전체 카테고리' : m,
                style: TextStyle(
                  fontWeight:
                      m == value ? FontWeight.w700 : FontWeight.w500,
                  color: m == value ? AppColors.primary : AppColors.text,
                )),
          ),
      ],
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final label = value.isEmpty ? '전체 카테고리' : value;
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => _open(context),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    )),
              ),
              const Icon(Icons.expand_more,
                  size: 18, color: AppColors.text3),
            ],
          ),
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
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
