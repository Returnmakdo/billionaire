import 'package:flutter/material.dart';

import '../theme.dart';

/// 대시보드 KPI 카드. primary=true면 강조 색상 (이번 달 지출).
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.unit = '원',
    this.delta,
    this.deltaExtra,
    this.primary = false,
  });
  final String label;
  final String value; // 큰 숫자
  final String unit;
  final String? delta;
  final String? deltaExtra;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.text;
    final fg2 = primary ? Colors.white.withValues(alpha: 0.85) : AppColors.text3;
    final bg = primary ? AppColors.primary : AppColors.surface;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 6, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                color: fg2,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.02,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(unit,
                  style: TextStyle(
                    color: fg2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Text(delta!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: fg2,
                  fontWeight: FontWeight.w500,
                )),
          ],
          if (deltaExtra != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(deltaExtra!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: fg2,
                    fontWeight: FontWeight.w500,
                  )),
            ),
        ],
      ),
    );
  }
}
