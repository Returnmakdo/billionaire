import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 숫자 입력 시 자동으로 천 단위 콤마를 찍는 TextInputFormatter.
class _ThousandsFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat.decimalPattern('ko_KR');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) {
      return TextEditingValue(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    final n = int.tryParse(raw);
    if (n == null) return oldValue;
    final formatted = _fmt.format(n);

    // caret 보존: 입력 전 caret까지 있던 디지트 수만큼 우측 인덱스로.
    final beforeCaretRaw = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    var pos = formatted.length;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) seen++;
      if (seen == beforeCaretRaw) {
        pos = i + 1;
        break;
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

/// 금액 입력 필드. 콤마 자동, 숫자 키패드.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = '금액 (원)',
    this.hint = '0',
  });
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [_ThousandsFormatter()],
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  /// 컨트롤러 텍스트 → int. null이면 0.
  static int? parse(TextEditingController c) {
    final raw = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  /// int → 컨트롤러 텍스트. 콤마 적용.
  static void setNumber(TextEditingController c, int? n) {
    if (n == null) {
      c.text = '';
    } else {
      c.text = NumberFormat.decimalPattern('ko_KR').format(n);
    }
  }
}
