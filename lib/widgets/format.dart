import 'package:intl/intl.dart';

final NumberFormat _wonFmt = NumberFormat.decimalPattern('ko_KR');

String won(num n) => _wonFmt.format(n.round());

/// 1천만 이상이면 자동 단축 표기, 그 미만은 정확한 원 단위.
/// 0.5억, 1234만, 1,234 같은 형태.
String smartWon(num n) {
  final v = n.round();
  final sign = v < 0 ? '-' : '';
  final abs = v.abs();
  if (abs >= 100000000) {
    final e = abs / 100000000;
    return '$sign${_trimZero(e.toStringAsFixed(2))}억';
  }
  if (abs >= 10000000) {
    final m = (abs / 10000).round();
    return '$sign${_wonFmt.format(m)}만';
  }
  return _wonFmt.format(v);
}

/// 차트 라벨용 짧은 표기 — 1만 이상부터 단축.
String wonShort(num n) {
  final v = n.round();
  if (v >= 100000000) {
    return '${_trimZero((v / 100000000).toStringAsFixed(1))}억';
  }
  if (v >= 10000) {
    final digits = v >= 100000 ? 0 : 1;
    return '${_trimZero((v / 10000).toStringAsFixed(digits))}만';
  }
  return _wonFmt.format(v);
}

String _trimZero(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceAll(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

String todayYm() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

String todayIso() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String shiftYm(String ym, int delta) {
  final parts = ym.split('-').map(int.parse).toList();
  final d = DateTime(parts[0], parts[1] + delta, 1);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

String ymLabel(String ym) {
  final parts = ym.split('-').map(int.parse).toList();
  return '${parts[0]}년 ${parts[1]}월';
}

const _dows = ['월', '화', '수', '목', '금', '토', '일'];

String dayOfWeekKo(String iso) {
  final d = DateTime.parse(iso);
  return _dows[d.weekday - 1];
}

String fmtDate(String iso) {
  if (iso.isEmpty) return '';
  final parts = iso.split('-');
  final m = int.parse(parts[1]);
  final d = int.parse(parts[2]);
  return '$m월 $d일 (${dayOfWeekKo(iso)})';
}
