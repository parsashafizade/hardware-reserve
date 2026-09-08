import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/error_presenter.dart';
import '../data/auth_models.dart';
import 'auth_scaffold.dart';

enum _ResetStep { email, code, password }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _ResetStep _step = _ResetStep.email;
  String? _resetToken;
  String? _error;
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (_step) {
        case _ResetStep.email:
          if (!_email.text.contains('@')) throw const FormatException();
          await ref
              .read(authRepositoryProvider)
              .forgotPassword(ForgotPasswordRequest(email: _email.text.trim()));
          if (mounted) setState(() => _step = _ResetStep.code);
        case _ResetStep.code:
          if (_code.text.trim().length != 6) throw const FormatException();
          final result = await ref
              .read(authRepositoryProvider)
              .verifyPasswordResetCode(
                VerifyPasswordResetCodeRequest(
                  email: _email.text.trim(),
                  code: _code.text.trim(),
                ),
              );
          if (mounted) {
            setState(() {
              _resetToken = result.resetToken;
              _step = _ResetStep.password;
            });
          }
        case _ResetStep.password:
          if (_password.text.length < 8 ||
              _password.text != _confirm.text ||
              _resetToken == null) {
            throw const FormatException();
          }
          await ref
              .read(authControllerProvider.notifier)
              .resetPassword(
                ResetPasswordRequest(
                  token: _resetToken!,
                  newPassword: _password.text,
                  confirmPassword: _confirm.text,
                ),
              );
          if (mounted) context.go('/');
      }
    } on FormatException {
      if (mounted) setState(() => _error = context.l10n.tr('error.validation'));
    } on Object catch (error) {
      if (mounted) setState(() => _error = presentError(context, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == _ResetStep.password
        ? context.l10n.tr('auth.newPassword')
        : context.l10n.tr('auth.forgotTitle');
    return AuthScaffold(
      title: title,
      subtitle: _step == _ResetStep.code
          ? context.l10n.tr('auth.verifyBody', {'email': _email.text.trim()})
          : context.l10n.tr('auth.loginSubtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step == _ResetStep.email)
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.tr('auth.identifier'),
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
            ),
          if (_step == _ResetStep.code)
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
          if (_step == _ResetStep.password) ...[
            TextField(
              controller: _password,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.tr('auth.newPassword'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.tr('auth.confirmPassword'),
                prefixIcon: const Icon(Icons.verified_user_outlined),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            AuthFeedback(message: _error!),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox.square(
                    dimension: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(context.l10n.tr('action.continue')),
          ),
          if (_step != _ResetStep.email)
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _step = _ResetStep.email;
                      _resetToken = null;
                      _error = null;
                    }),
              child: Text(context.l10n.tr('action.cancel')),
            ),
        ],
      ),
    );
  }
}
