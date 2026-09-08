import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/error_presenter.dart';
import '../../../core/widgets/first_strong_text.dart';
import '../data/auth_models.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
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
      final value = await ref.read(authRepositoryProvider).getCaptcha();
      if (mounted) {
        setState(() {
          _captcha = value;
          _captchaAnswer.clear();
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = presentError(context, error));
    }
  }

  Future<void> _submit() async {
    if (_loading || _captcha == null || !_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .register(
            RegisterRequest(
              fullName: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
              captchaId: _captcha!.captchaId,
              captchaAnswer: int.parse(_captchaAnswer.text.trim()),
            ),
          );
      if (mounted) {
        context.pushReplacement(
          '/verify-email?email=${Uri.encodeQueryComponent(result.email)}',
        );
      }
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
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _captchaAnswer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.l10n.tr('action.register'),
      subtitle: context.l10n.tr('home.body'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _name,
              builder: (context, value, _) => TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textDirection: value.text.trim().isEmpty
                    ? Directionality.of(context)
                    : firstStrongTextDirection(value.text),
                textAlign: TextAlign.start,
                decoration: InputDecoration(
                  labelText: context.l10n.tr('auth.fullName'),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: _required,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.tr('auth.identifier'),
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) => value != null && value.contains('@')
                  ? null
                  : context.l10n.tr('error.validation'),
            ),
            const SizedBox(height: 12),
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
              validator: (value) => (value?.length ?? 0) < 8
                  ? context.l10n.tr('error.validation')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.tr('auth.confirmPassword'),
                prefixIcon: const Icon(Icons.verified_user_outlined),
              ),
              validator: (value) => value == _password.text
                  ? null
                  : context.l10n.tr('error.validation'),
            ),
            const SizedBox(height: 12),
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
                  : Text(context.l10n.tr('action.register')),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.pushReplacement('/login'),
              child: Text(context.l10n.tr('action.login')),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.l10n.tr('error.validation')
      : null;
}
