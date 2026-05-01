import 'package:flutter/material.dart';

import '../theme.dart';

/// 로딩 상태 placeholder. 살짝 pulse 애니메이션.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.shape = BoxShape.rectangle,
    this.radius,
  });
  final double? width;
  final double height;
  final BoxShape shape;
  final double? radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final color = Color.lerp(
          AppColors.line2,
          AppColors.line,
          _ctrl.value,
        );
        if (widget.shape == BoxShape.circle) {
          return Container(
            width: widget.width ?? widget.height,
            height: widget.height,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          );
        }
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.radius ?? 8),
          ),
        );
      },
    );
  }
}

/// 한 줄 텍스트 placeholder.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.width, this.height = 12});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Skeleton(width: width, height: height, radius: 4);
  }
}

/// 카드 안에서 쓰는 표준 패딩 박스.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.height,
    this.padding = const EdgeInsets.all(18),
  });
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 6,
              offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLine(width: 60, height: 11),
          const SizedBox(height: 8),
          SkeletonLine(width: height * 0.8, height: 22),
          const Spacer(),
          const SkeletonLine(width: 90, height: 11),
        ],
      ),
    );
  }
}
