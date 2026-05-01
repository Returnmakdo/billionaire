import 'package:flutter/material.dart';

import '../theme.dart';
import 'category_color.dart';
import 'format.dart';

/// 태그/가맹점 TOP N 리스트의 한 줄.
/// rank, 카테고리 점, 이름(+sub 회색), 비례 막대, 금액·건수.
class MerchantItem extends StatelessWidget {
  const MerchantItem({
    super.key,
    required this.rank,
    required this.major,
    required this.title,
    this.subtitle,
    required this.amount,
    required this.count,
    this.onTap,
  });
  final int rank;
  final String major;
  final String title;
  final String? subtitle;
  final int amount;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text('$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  fontFeatures: [FontFeature.tabularFigures()],
                )),
          ),
          const SizedBox(width: 8),
          CategoryDot(major, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                  if (subtitle != null) ...[
                    const TextSpan(text: '  '),
                    TextSpan(
                        text: subtitle,
                        style: TextStyle(
                          color: AppColors.text3,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        )),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${won(amount)}원',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
              const SizedBox(height: 2),
              Text('$count건',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.text3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
