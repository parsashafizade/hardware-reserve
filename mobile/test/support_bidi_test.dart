import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/features/support/presentation/support_presentation_helpers.dart';

void main() {
  test('mixed support messages use their first strong character', () {
    expect(
      firstStrongTextDirection('سرور RTX 4090 من هنوز active نشده؟'),
      TextDirection.rtl,
    );
    expect(
      firstStrongTextDirection('IP من 192.168.1.20 هست ولی SSH کار نمی‌کند.'),
      TextDirection.ltr,
    );
    expect(
      firstStrongTextDirection('لطفاً reservation ID: HR-20491 را بررسی کنید.'),
      TextDirection.rtl,
    );
  });
}
