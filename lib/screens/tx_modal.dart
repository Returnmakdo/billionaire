import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/ko_date_picker.dart';

enum TxModalResult { changed, none }

Future<TxModalResult> showTxModal(
  BuildContext context, {
  required CategoriesData cats,
  required Suggestions suggestions,
  Tx? tx,
}) async {
  final r = await showModalBottomSheet<TxModalResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => _TxModal(cats: cats, suggestions: suggestions, tx: tx),
  );
  return r ?? TxModalResult.none;
}

class _TxModal extends StatefulWidget {
  const _TxModal({
    required this.cats,
    required this.suggestions,
    this.tx,
  });
  final CategoriesData cats;
  final Suggestions suggestions;
  final Tx? tx;

  @override
  State<_TxModal> createState() => _TxModalState();
}

class _TxModalState extends State<_TxModal> {
  late final TextEditingController _date;
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _card;
  late final TextEditingController _memo;
  late String _major;
  String? _sub;
  late bool _isFixed;
  bool _saving = false;

  bool get _editing => widget.tx != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.tx;
    final majors = widget.cats.majors;
    _major = tx?.majorCategory ?? (majors.isNotEmpty ? majors.first : '');
    _sub = tx?.subCategory;
    _date = TextEditingController(text: tx?.date ?? todayIso());
    _amount = TextEditingController();
    AmountField.setNumber(_amount, tx?.amount);
    _merchant = TextEditingController(text: tx?.merchant ?? '');
    _card = TextEditingController(text: tx?.card ?? '');
    _memo = TextEditingController(text: tx?.memo ?? '');
    _isFixed = tx?.isFixed ?? false;
  }

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    _merchant.dispose();
    _card.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date.text) ?? DateTime.now();
    final picked = await showKoDatePicker(
      context: context,
      initial: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _date.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _save() async {
    final amount = AmountField.parse(_amount);
    if (_date.text.isEmpty || _major.isEmpty || amount == null || amount == 0) {
      showToast(context, '날짜, 금액, 카테고리는 필수예요', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_editing) {
        await Api.instance.updateTransaction(
          widget.tx!.id,
          date: _date.text,
          card: _card.text,
          merchant: _merchant.text,
          amount: amount,
          majorCategory: _major,
          subCategory: _sub ?? '',
          memo: _memo.text,
          isFixed: _isFixed,
        );
      } else {
        await Api.instance.createTransaction(
          date: _date.text,
          card: _card.text.isEmpty ? null : _card.text,
          merchant: _merchant.text.isEmpty ? null : _merchant.text,
          amount: amount,
          majorCategory: _major,
          subCategory: (_sub?.isEmpty ?? true) ? null : _sub,
          memo: _memo.text.isEmpty ? null : _memo.text,
          isFixed: _isFixed,
        );
      }
      if (!mounted) return;
      showToast(context, _editing ? '수정했어요' : '추가했어요');
      Navigator.of(context).pop(TxModalResult.changed);
    } catch (e) {
      if (!mounted) return;
      showToast(context, errorMessage(e), error: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final tx = widget.tx;
    if (tx == null) return;
    final ok = await confirmDialog(
      context,
      title: '거래 삭제',
      message: '"${tx.merchant ?? '이 거래'}"를 삭제할까요?',
      confirmText: '삭제',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.instance.deleteTransaction(tx.id);
      if (!mounted) return;
      showToast(context, '삭제했어요');
      Navigator.of(context).pop(TxModalResult.changed);
    } catch (e) {
      if (!mounted) return;
      showToast(context, errorMessage(e), error: true);
    }
  }

  Future<void> _registerAsFixed() async {
    final tx = widget.tx;
    if (tx == null) return;
    final name = tx.merchant?.trim() ?? '';
    if (name.isEmpty) {
      showToast(context, '가맹점 이름이 있어야 등록할 수 있어요', error: true);
      return;
    }
    final day =
        int.tryParse(tx.date.split('-').last) ?? DateTime.now().day;
    try {
      final list = await Api.instance.listFixedExpenses();
      if (!mounted) return;
      final dup = list.any((f) =>
          f.name == name && f.major == tx.majorCategory && f.active);
      if (dup) {
        showToast(context, '이미 정기지출에 등록되어 있어요', error: true);
        return;
      }
      final ok = await confirmDialog(
        context,
        title: '정기지출 등록',
        message:
            '"$name"을 매월 $day일 결제되는 정기지출로 등록할까요?\n나중에 정기지출 탭에서 수정할 수 있어요.',
        confirmText: '등록',
      );
      if (!ok || !mounted) return;
      await Api.instance.createFixedExpense(
        name: name,
        major: tx.majorCategory,
        sub: tx.subCategory,
        amount: tx.amount,
        card: tx.card,
        dayOfMonth: day,
        active: true,
        memo: tx.memo,
      );
      if (!mounted) return;
      showToast(context, '정기지출로 등록했어요');
      Navigator.of(context).pop(TxModalResult.changed);
    } catch (e) {
      if (!mounted) return;
      showToast(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final subs = widget.cats.byMajor[_major] ?? const [];
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
                  Text(_editing ? '거래 수정' : '거래 추가',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      )),
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
                    _dateField(),
                    const SizedBox(height: 12),
                    AmountField(controller: _amount),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _majorDropdown()),
                        const SizedBox(width: 10),
                        Expanded(child: _subDropdown(subs)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _fieldWithChips(
                      controller: _merchant,
                      label: '가맹점',
                      hint: '예: 스타벅스',
                      options: _merchantSuggestions(),
                      emptyHint: _major.isEmpty
                          ? null
                          : '$_major에 등록된 가맹점이 없어요',
                    ),
                    const SizedBox(height: 12),
                    _fieldWithChips(
                      controller: _card,
                      label: '카드/결제수단',
                      hint: '예: KB, 현대, 현금',
                      options: widget.suggestions.cards,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _memo,
                      decoration: const InputDecoration(
                          labelText: '메모', hintText: '선택'),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() {
                        _isFixed = !_isFixed;
                      }),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: Row(
                          children: [
                            Switch(
                              value: _isFixed,
                              onChanged: (v) => setState(() {
                                _isFixed = v;
                              }),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('고정비로 표시',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text)),
                                  SizedBox(height: 2),
                                  Text('월세, 구독료처럼 매달 정해진 지출',
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
                      TextButton.icon(
                        onPressed: _registerAsFixed,
                        icon: const Icon(Icons.repeat, size: 18),
                        label: const Text('정기지출로 등록',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('이 거래 삭제',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          alignment: Alignment.centerLeft,
                        ),
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
                child: Text(_editing ? '저장' : '추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextField(
          controller: _date,
          decoration: const InputDecoration(
            labelText: '날짜',
            suffixIcon:
                Icon(Icons.calendar_today, size: 18, color: AppColors.text3),
          ),
        ),
      ),
    );
  }

  Widget _majorDropdown() {
    final majors = widget.cats.majors;
    return AppDropdown<String>(
      label: '카테고리',
      value: majors.contains(_major) ? _major : null,
      items: [
        for (final m in majors) AppDropdownItem(value: m, label: m),
      ],
      onChanged: (v) {
        setState(() {
          _major = v;
          _sub = null;
        });
      },
    );
  }

  Widget _subDropdown(List<Category> subs) {
    return AppDropdown<String>(
      label: '태그',
      value: _sub ?? '',
      items: [
        const AppDropdownItem(value: '', label: '(없음)'),
        for (final s in subs) AppDropdownItem(value: s.sub, label: s.sub),
      ],
      onChanged: (v) => setState(() => _sub = v.isEmpty ? null : v),
    );
  }

  List<String> _merchantSuggestions() {
    if (_major.isEmpty) return const [];
    return widget.suggestions.merchantsByMajor[_major] ?? const [];
  }

  Widget _fieldWithChips({
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> options,
    String? emptyHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, hintText: hint),
          onChanged: (_) => setState(() {}),
        ),
        if (options.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final o in options)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _PickChip(
                        label: o,
                        selected: controller.text == o,
                        onTap: () => setState(() {
                          controller.text = o;
                          controller.selection =
                              TextSelection.collapsed(offset: o.length);
                        }),
                      ),
                    ),
                ],
              ),
            ),
          )
        else if (emptyHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              emptyHint,
              style: const TextStyle(fontSize: 11.5, color: AppColors.text4),
            ),
          ),
      ],
    );
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryWeak : AppColors.surface2,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primaryStrong : AppColors.text2,
            ),
          ),
        ),
      ),
    );
  }
}
