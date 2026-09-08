import 'dart:async';

import 'package:flutter/widgets.dart';

class RefreshOnResume extends StatefulWidget {
  const RefreshOnResume({
    super.key,
    required this.onResume,
    required this.child,
  });

  final FutureOr<void> Function() onResume;
  final Widget child;

  @override
  State<RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends State<RefreshOnResume>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(Future<void>.sync(widget.onResume));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
