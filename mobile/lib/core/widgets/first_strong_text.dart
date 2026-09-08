import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

/// Chooses direction from the first strong character in dynamic content.
/// Technical and number-led values fall back to LTR for readability.
TextDirection firstStrongTextDirection(String text) {
  if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
  if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
  return TextDirection.ltr;
}

class FirstStrongText extends StatelessWidget {
  const FirstStrongText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: firstStrongTextDirection(text),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
