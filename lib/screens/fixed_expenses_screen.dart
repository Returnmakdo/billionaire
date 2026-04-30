import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/category_color.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

class FixedExpensesScreen extends StatefulWidget {
  const FixedExpensesScreen({super.key});

  @override
  State<FixedExpensesScreen> createState() => _FixedExpensesScreenState();
}

class _FixedExpensesScreenState extends State<FixedExpensesScreen> {
  _FixedData? _data;
  Object? _error;

  late final Listenable _apiListenable = Listenable.merge([
    Api.instance.fixedVersion,
    Api.instance.majorsVersion,
    Api.instance.categoriesVersion,
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
        api.listFixedExpenses(),
        api.listCategories(),
      ]);
      Suggestions sug;
      try {
        sug = await api.getSuggestions();
      } catch (_) {
        sug = const Suggestions(merchants: [], cards: []);
      }
      if (!mounted) return;
      setState(() {
        _data = _FixedData(
          items: results[0] as List<FixedExpense>,
          cats: results[1] as CategoriesData,
          suggestions: sug,
        );
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _openModal(_FixedData d, [FixedExpense? item]) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _FixedModal(
        cats: d.cats,
        suggestions: d.suggestions,
        item: item,
      ),
    );
    if (r == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _data == null ? null : () => _openModal(_data!),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('정기지출 추가'),
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
            final active =
                d.items.where((it) => it.active).toList();
            final inactive =
                d.items.where((it) => !it.active).toList();
            final totalActive =
                active.fold<int>(0, (s, x) => s + x.amount);

            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
              children: [
                const PageHeader(
                  title: '정기지출',
                  subtitle: '매달 반복되는 지출을 등록해두세요.',
                ),
                if (d.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: EmptyCard(
                      title: '등록된 정기지출이 없어요',
                      body: '아래 + 버튼으로 월세·구독 등을 등록하세요.',
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: AppCard(
                      tight: true,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('활성 ${active.length}개의 월 합계',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.text3,
                                fontWeight: FontWeight.w500,
                              )),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(won(totalActive),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                    letterSpacing: -0.01,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  )),
                              const SizedBox(width: 4),
                              const Text('원',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.text3,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final it in active)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FixedRow(
                              item: it,
                              onTap: () => _openModal(d, it),
                            ),
                          ),
                        if (inactive.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('비활성',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text3,
                                  )),
                            ),
                          ),
                          for (final it in inactive)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Opacity(
                                opacity: 0.55,
                                child: _FixedRow(
                                  item: it,
                                  onTap: () => _openModal(d, it),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FixedRow extends StatelessWidget {
  const _FixedRow({required this.item, required this.onTap});
  final FixedExpense item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = StringBuffer(item.major);
    if (item.sub?.isNotEmpty ?? false) meta.write(' · ${item.sub}');
    meta.write(' · 매월 ${item.dayOfMonth}일');
    if (item.card?.isNotEmpty ?? false) meta.write(' · ${item.card}');
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          CategoryDot(item.major, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          )),
                    ),
                    if (!item.active) ...[
                      const SizedBox(width: 6),
                      const Pill(
                          label: '비활성',
                          color: AppColors.text3,
                          bg: AppColors.surface2),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(meta.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.text3,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${won(item.amount)}원',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                fontFeatures: [FontFeature.tabularFigures()],
              )),
          const Icon(Icons.chevron_right,
              color: AppColors.text4, size: 20),
        ],
      ),
    );
  }
}

class _FixedModal extends StatefulWidget {
  const _FixedModal({
    required this.cats,
    required this.suggestions,
    this.item,
  });
  final CategoriesData cats;
  final Suggestions suggestions;
  final FixedExpense? item;

  @override
  State<_FixedModal> createState() => _FixedModalState();
}

class _FixedModalState extends State<_FixedModal> {
  late final TextEditingController _name;
  late final TextEditingController _day;
  late final TextEditingController _amount;
  late final TextEditingController _card;
  late final TextEditingController _memo;
  late String _major;
  String? _sub;
  late bool _active;
  bool _saving = false;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _name = TextEditingController(text: it?.name ?? '');
    _day = TextEditingController(text: '${it?.dayOfMonth ?? 1}');
    _amount = TextEditingController();
    AmountField.setNumber(_amount, it?.amount);
    _card = TextEditingController(text: it?.card ?? '');
    _memo = TextEditingController(text: it?.memo ?? '');
    final majors = widget.cats.majors;
    _major = it?.major ?? (majors.isNotEmpty ? majors.first : '');
    _sub = it?.sub;
    _active = it?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _day.dispose();
    _amount.dispose();
    _card.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _major.isEmpty) {
      showToast(context, '이름과 카테고리는 필수예요', error: true);
      return;
    }
    final amount = AmountField.parse(_amount) ?? 0;
    final day = int.tryParse(_day.text.trim()) ?? 1;
    setState(() => _saving = true);
    try {
      if (_editing) {
        await Api.instance.updateFixedExpense(
          widget.item!.id,
          name: name,
          major: _major,
          sub: _sub ?? '',
          amount: amount,
          card: _card.text,
          dayOfMonth: day,
          active: _active,
          memo: _memo.text,
        );
      } else {
        await Api.instance.createFixedExpense(
          name: name,
          major: _major,
          sub: (_sub?.isEmpty ?? true) ? null : _sub,
          amount: amount,
          card: _card.text.isEmpty ? null : _card.text,
          dayOfMonth: day,
          active: _active,
          memo: _memo.text.isEmpty ? null : _memo.text,
        );
      }
      if (!mounted) return;
      showToast(context, _editing ? '수정했어요' : '등록했어요');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, errorMessage(e), error: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final it = widget.item;
    if (it == null) return;
    final ok = await confirmDialog(
      context,
      title: '정기지출 삭제',
      message: '"${it.name}"을 삭제할까요? (이미 등록된 거래내역은 영향 없음)',
      confirmText: '삭제',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.instance.deleteFixedExpense(it.id);
      if (!mounted) return;
      showToast(context, '삭제했어요');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final subs = widget.cats.byMajor[_major] ?? const [];
    final subValues = ['', ...subs.map((s) => s.sub)];
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
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
                  Text(_editing ? '정기지출 수정' : '정기지출 등록',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.text3),
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
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: '이름', hintText: '예: 월세, 넷플릭스'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _day,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: '매월 며칠'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AmountField(controller: _amount),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppDropdown<String>(
                            label: '카테고리',
                            value: widget.cats.majors.contains(_major)
                                ? _major
                                : null,
                            items: [
                              for (final m in widget.cats.majors)
                                AppDropdownItem(value: m, label: m),
                            ],
                            onChanged: (v) => setState(() {
                              _major = v;
                              _sub = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppDropdown<String>(
                            label: '태그',
                            value: _sub ?? '',
                            items: [
                              for (final v in subValues)
                                AppDropdownItem(
                                  value: v,
                                  label: v.isEmpty ? '(없음)' : v,
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _sub = v.isEmpty ? null : v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _card,
                      decoration: const InputDecoration(
                        labelText: '카드/결제수단',
                        hintText: '선택: 자동이체, 카드명 등',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _memo,
                      decoration: const InputDecoration(
                          labelText: '메모', hintText: '선택'),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() => _active = !_active),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: Row(
                          children: [
                            Switch(
                              value: _active,
                              onChanged: (v) =>
                                  setState(() => _active = v),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('활성',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.text)),
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message:
                                            '거래내역의 "정기지출 일괄 등록"을 누르면 활성 정기지출이 그 달 거래로 자동 추가돼요.',
                                        triggerMode:
                                            TooltipTriggerMode.tap,
                                        showDuration:
                                            const Duration(seconds: 4),
                                        preferBelow: true,
                                        textStyle: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.text,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 10,
                                            vertical: 8),
                                        child: const Icon(
                                            Icons.info_outline,
                                            size: 16,
                                            color: AppColors.text3),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('꺼두면 일괄 등록에서 제외돼요',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.text3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_editing) ...[
                      const SizedBox(height: 8),
                      const Divider(color: AppColors.line2, height: 1),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _delete,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          alignment: Alignment.centerLeft,
                        ),
                        child: const Text('이 항목 삭제',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 12 + mq.padding.bottom * 0.4),
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.line2)),
              ),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_editing ? '저장' : '등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedData {
  final List<FixedExpense> items;
  final CategoriesData cats;
  final Suggestions suggestions;
  const _FixedData({
    required this.items,
    required this.cats,
    required this.suggestions,
  });
}
