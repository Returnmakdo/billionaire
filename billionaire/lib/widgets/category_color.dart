import 'package:flutter/material.dart';

class CatColor {
  final Color bg;
  final Color fg;
  const CatColor({required this.bg, required this.fg});
}

const _palette = <CatColor>[
  CatColor(bg: Color(0xFFFFF1E0), fg: Color(0xFFC2410C)), // 오렌지
  CatColor(bg: Color(0xFFE0EDFF), fg: Color(0xFF1D4ED8)), // 블루
  CatColor(bg: Color(0xFFFDE8F1), fg: Color(0xFFBE185D)), // 핑크
  CatColor(bg: Color(0xFFDCFCE7), fg: Color(0xFF15803D)), // 그린
  CatColor(bg: Color(0xFFEDE9FE), fg: Color(0xFF6D28D9)), // 퍼플
  CatColor(bg: Color(0xFFFEE2E2), fg: Color(0xFFB91C1C)), // 레드
  CatColor(bg: Color(0xFFE0E7FF), fg: Color(0xFF4338CA)), // 인디고
  CatColor(bg: Color(0xFFF3F4F6), fg: Color(0xFF4B5563)), // 그레이
];

const _fixed = <String, int>{
  '식비': 0,
  '교통': 1,
  '여가/게임': 2,
  '쇼핑/생활': 3,
  '구독': 4,
  '의료': 5,
  '주거': 6,
  '기타': 7,
};

int _hashIdx(String s, int mod) {
  var h = 0;
  for (final code in s.codeUnits) {
    h = ((h << 5) - h + code) & 0xFFFFFFFF;
  }
  return h.abs() % mod;
}

CatColor categoryColor(String? major) {
  final m = major ?? '';
  final idx = _fixed[m] ?? _hashIdx(m, _palette.length);
  return _palette[idx];
}

/// 카테고리 식별용 동그란 색칠 점.
class CategoryDot extends StatelessWidget {
  const CategoryDot(this.major, {super.key, this.size = 36});
  final String major;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = categoryColor(major);
    final letter = major.isEmpty ? '?' : major.substring(0, 1);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: c.fg,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
