import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme.dart';
import 'category_color.dart';
import 'common.dart';
import 'format.dart';

/// 거래내역 한 줄.
class TxRow extends StatelessWidget {
  const TxRow({
    super.key,
    required this.tx,
    this.isRecurring = false,
    this.onTap,
  });
  final Tx tx;
  final bool isRecurring;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = StringBuffer(tx.majorCategory);
    if (tx.subCategory?.isNotEmpty ?? false) meta.write(' · ${tx.subCategory}');
    if (tx.card?.isNotEmpty ?? false) meta.write(' · ${tx.card}');
    if (tx.memo?.isNotEmpty ?? false) meta.write(' · ${tx.memo}');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            CategoryDot(tx.majorCategory, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tx.merchant?.isNotEmpty == true
                              ? tx.merchant!
                              : '(가맹점 없음)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (tx.isFixed) ...[
                        const SizedBox(width: 6),
                        const Pill(
                            label: '고정',
                            color: AppColors.primary,
                            bg: AppColors.primaryWeak),
                      ],
                      if (isRecurring) ...[
                        const SizedBox(width: 4),
                        const Pill(
                            label: '정기',
                            color: AppColors.success,
                            bg: Color(0xFFDFF7EB)),
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
            Text('${won(tx.amount)}원',
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
      ),
    );
  }
}

/// 날짜 그룹 헤더.
class TxDayHeader extends StatelessWidget {
  const TxDayHeader({super.key, required this.date, required this.total});
  final String date; // YYYY-MM-DD
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(fmtDate(date),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text3,
              )),
          Text('${won(total)}원',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text3,
                fontFeatures: [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}
