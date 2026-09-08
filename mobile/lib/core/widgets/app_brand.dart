import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({super.key, this.inverse = false, this.compact = false});

  final bool inverse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledLabelSize = MediaQuery.textScalerOf(context).scale(16);
        final showWordmark =
            !compact &&
            scaledLabelSize <= 21 &&
            (!constraints.hasBoundedWidth || constraints.maxWidth >= 280);
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: inverse
                      ? null
                      : const LinearGradient(
                          colors: [AppColors.brand600, AppColors.brand400],
                        ),
                  color: inverse ? Colors.white.withValues(alpha: .10) : null,
                  border: Border.all(
                    color: inverse ? Colors.white24 : AppColors.brand300,
                  ),
                  boxShadow: inverse
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x33247FF2),
                            blurRadius: 22,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.dns_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                    Positioned(
                      right: 7,
                      bottom: 6,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: inverse ? AppColors.brand300 : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: inverse
                                ? AppColors.inverse
                                : AppColors.brand600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showWordmark) ...[
                const SizedBox(width: 10),
                Text.rich(
                  TextSpan(
                    text: 'Hardware',
                    children: [
                      TextSpan(
                        text: 'Reserve',
                        style: TextStyle(
                          color: inverse
                              ? AppColors.brand300
                              : AppColors.brand600,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: null,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: inverse ? Colors.white : AppColors.ink950,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
