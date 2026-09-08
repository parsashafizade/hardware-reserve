import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/role_navigation.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/error_presenter.dart';
import '../data/auth_models.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.returnPath});
  final String? returnPath;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _captchaAnswer = TextEditingController();
  CaptchaChallengeResponse? _captcha;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  Future<void> _loadCaptcha() async {
    try {
      final challenge = await ref.read(authRepositoryProvider).getCaptcha();
      if (mounted) {
        setState(() {
          _captcha = challenge;
          _captchaAnswer.clear();
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = presentError(context, error));
    }
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate() || _captcha == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .login(
            LoginRequest(
              identifier: _identifier.text.trim(),
              password: _password.text,
              captchaId: _captcha!.captchaId,
              captchaAnswer: int.parse(_captchaAnswer.text.trim()),
            ),
          );
      if (!mounted) return;
      context.go(authenticatedLandingPath(
        session.user,
        requestedPath: widget.returnPath,
      ));
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = presentError(context, error));
        await _loadCaptcha();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _captchaAnswer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.l10n.tr('auth.welcome'),
      subtitle: context.l10n.tr('auth.loginSubtitle'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _identifier,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.tr('auth.identifier'),
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.l10n.tr('error.validation')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.tr('auth.password'),
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
              validator: (value) => value == null || value.isEmpty
                  ? context.l10n.tr('error.validation')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _captchaAnswer,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: _captcha == null
                    ? context.l10n.tr('common.loading')
                    : context.l10n.tr('auth.captcha', {
                        'a': _captcha!.a,
                        'b': _captcha!.b,
                      }),
                prefixIcon: IconButton(
                  onPressed: _loadCaptcha,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              validator: (value) => int.tryParse(value?.trim() ?? '') == null
                  ? context.l10n.tr('error.validation')
                  : null,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: Text(context.l10n.tr('auth.forgot')),
              ),
            ),
            if (_error != null) ...[
              AuthFeedback(message: _error!),
              const SizedBox(height: 14),
            ],
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
                  : Text(context.l10n.tr('action.login')),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.push('/register'),
              child: Text(context.l10n.tr('action.register')),
            ),
          ],
        ),
      ),
    );
  }
}
