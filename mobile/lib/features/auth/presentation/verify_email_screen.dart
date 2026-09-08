import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/error_presenter.dart';
import '../data/auth_models.dart';
import 'auth_scaffold.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});
  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _resendSeconds = 60;
  bool _loading = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (_loading || code.length != 6) {
      setState(() => _error = context.l10n.tr('error.validation'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyEmail(VerifyEmailRequest(email: widget.email, code: code));
      if (mounted) context.go('/');
    } on Object catch (error) {
      if (mounted) setState(() => _error = presentError(context, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    try {
      await ref
          .read(authRepositoryProvider)
          .resendVerificationCode(
            ResendVerificationCodeRequest(email: widget.email),
          );
      if (mounted) {
        setState(() => _message = context.l10n.tr('auth.resend'));
        _startCountdown();
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = presentError(context, error));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.l10n.tr('auth.verifyTitle'),
      subtitle: context.l10n.tr('auth.verifyBody', {'email': widget.email}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _code,
            autofocus: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(letterSpacing: 8),
            decoration: InputDecoration(
              labelText: context.l10n.tr('auth.code'),
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthFeedback(message: _error!),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            AuthFeedback(message: _message!, success: true),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading ? null : _verify,
            child: _loading
                ? const SizedBox.square(
                    dimension: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(context.l10n.tr('action.confirm')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _resendSeconds == 0 ? _resend : null,
            child: Text(
              _resendSeconds == 0
                  ? context.l10n.tr('auth.resend')
                  : '${context.l10n.tr('auth.resend')} ($_resendSeconds)',
            ),
          ),
        ],
      ),
    );
  }
}
