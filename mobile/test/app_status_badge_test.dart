import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/theme/app_theme.dart';
import 'package:hardware_reserve/core/widgets/app_status_badge.dart';

void main() {
  testWidgets('default semantic badge labels meet normal-text contrast', (
    tester,
  ) async {
    const semanticColors = <String, Color>{
      'brand': AppColors.brand500,
      'success': AppColors.success,
      'warning': AppColors.warning,
      'danger': AppColors.danger,
      'info': AppColors.info,
      'neutral': AppColors.ink500,
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(const Locale('en')),
        home: Material(
          color: Colors.white,
          child: Column(
            children: [
              for (final entry in semanticColors.entries)
                AppStatusBadge(label: entry.key, color: entry.value),
            ],
          ),
        ),
      ),
    );

    for (final entry in semanticColors.entries) {
      final text = tester.widget<Text>(find.text(entry.key));
      final foreground = text.style!.color!;
      final background = Color.alphaBlend(
        entry.value.withValues(alpha: .09),
        Colors.white,
      );

      expect(
        _contrastRatio(foreground, background),
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key} badge text must remain readable',
      );
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + .05) / (darker + .05);
}
