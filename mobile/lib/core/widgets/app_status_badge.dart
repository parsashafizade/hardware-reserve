import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.textStyle,
    this.backgroundAlpha = .09,
    this.borderAlpha = .24,
  });

  final String label;
  final Color color;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final double backgroundAlpha;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = color.withValues(alpha: backgroundAlpha);
    // Semantic colors are intentionally vivid, but most do not have enough
    // contrast for small text on their pale badge tint. Keep the indicator in
    // the original color and darken only the default label foreground.
    final foregroundColor = Color.lerp(color, AppColors.ink950, .25)!;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style:
                textStyle ??
                Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
