import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';
import 'format.dart';

/// 카테고리별 변동비 진행률 카드.
class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.major,
    required this.spent,
    required this.budget,
    this.onTap,
  });
  final String major;
  final int spent; // variable_spent
  final int budget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final noBudget = budget == 0;
    final pct = noBudget ? 0.0 : (spent / budget).clamp(0.0, 999.0);
    final pctClamped = pct > 1.0 ? 1.0 : pct;
    final pctText = '${(pct * 100).round()}%';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(major,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    )),
              ),
              Text(pctText,
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
          const SizedBox(height: 8),
          _amountLine(noBudget),
          const SizedBox(height: 12),
          ProgressTrack(percent: pctClamped),
        ],
      ),
    );
  }

  Widget _amountLine(bool noBudget) {
    final spentText = '${won(spent)}원';
    final budgetText = noBudget ? '예산 미설정' : '/ ${won(budget)}원';
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13.5,
          color: AppColors.text2,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        children: [
          TextSpan(
              text: spentText,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              )),
          const TextSpan(text: ' '),
          TextSpan(
              text: budgetText,
              style: TextStyle(
                color: noBudget ? AppColors.text3 : AppColors.text2,
              )),
        ],
      ),
    );
  }
}
