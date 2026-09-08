import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/error_presenter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/first_strong_text.dart';
import '../data/email_change_models.dart';
import '../data/profile_model.dart';

final _profileProvider = FutureProvider.autoDispose<ProfileModel>(
  (ref) => ref.watch(profileRepositoryProvider).getProfile(),
);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(_profileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('profile.title'))),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_profileProvider),
        child: profile.when(
          loading: () => const AppLoadingView(),
          error: (error, _) => ListView(
            children: [
              SizedBox(
                height: 500,
                child: AppErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(_profileProvider),
                ),
              ),
            ],
          ),
          data: (value) => _ProfileBody(profile: value),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});
  final ProfileModel profile;
  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.fullName,
  );
  bool _saving = false;
  bool _uploading = false;
  String? _error;
  String? _failedProfileImageUrl;

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateProfile(_name.text);
      ref.invalidate(_profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.tr('profile.saved'))),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = presentError(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    if (_uploading) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null || !mounted) return;

      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : '';
      if (!const <String>{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        setState(() => _error = context.l10n.tr('profile.imageUnsupported'));
        return;
      }
      if (await image.length() > 1900 * 1024) {
        if (mounted) {
          setState(() => _error = context.l10n.tr('profile.imageTooLarge'));
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _uploading = true;
        _error = null;
      });
      await ref
          .read(profileRepositoryProvider)
          .uploadProfileImage(image.path, fileName: image.name);
      ref.invalidate(_profileProvider);
    } on Object catch (error) {
      if (mounted) setState(() => _error = presentError(context, error));
    } finally {
      if (mounted && _uploading) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeControllerProvider);
    final isAdmin = ref.watch(
      authControllerProvider.select(
        (state) => state.session?.user.isAdmin ?? false,
      ),
    );
    final profileImageUrl = widget.profile.profileImageUrl;
    final canShowProfileImage =
        profileImageUrl != null && profileImageUrl != _failedProfileImageUrl;
    final trimmedName = widget.profile.fullName.trim();
    final profileInitial = trimmedName.isEmpty
        ? '?'
        : trimmedName.characters.first.toUpperCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.brand100,
                      backgroundImage: canShowProfileImage
                          ? NetworkImage(profileImageUrl)
                          : null,
                      onBackgroundImageError: canShowProfileImage
                          ? (_, _) {
                              if (mounted) {
                                setState(
                                  () =>
                                      _failedProfileImageUrl = profileImageUrl,
                                );
                              }
                            }
                          : null,
                      child: !canShowProfileImage
                          ? Text(
                              profileInitial,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: AppColors.brand700),
                            )
                          : null,
                    ),
                    PositionedDirectional(
                      end: -4,
                      bottom: -4,
                      child: IconButton.filled(
                        tooltip: context.l10n.tr('profile.image'),
                        onPressed: _uploading ? null : _pickImage,
                        icon: _uploading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.photo_camera_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _name,
                  builder: (context, value, _) => TextField(
                    controller: _name,
                    textDirection: value.text.trim().isEmpty
                        ? Directionality.of(context)
                        : firstStrongTextDirection(value.text),
                    textAlign: TextAlign.start,
                    decoration: InputDecoration(
                      labelText: context.l10n.tr('profile.name'),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: widget.profile.email,
                  enabled: false,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('profile.email'),
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(context.l10n.tr('action.save')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(context.l10n.tr('profile.language')),
                subtitle: Text(
                  locale.languageCode == 'fa' ? 'فارسی' : 'English',
                ),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fa', label: Text('فا')),
                    ButtonSegment(value: 'en', label: Text('EN')),
                  ],
                  selected: {locale.languageCode},
                  onSelectionChanged: (value) => ref
                      .read(localeControllerProvider.notifier)
                      .setLanguage(value.first),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.mark_email_read_outlined),
                title: Text(context.l10n.tr('profile.emailChange')),
                subtitle: Text(context.l10n.tr('profile.emailChangeHelp')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const _EmailChangeSheet(),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(
                  AppFormat.dateTime(context, widget.profile.createdAt),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (isAdmin) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(context.l10n.tr('admin.entry.title')),
              subtitle: Text(context.l10n.tr('admin.entry.subtitle')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/admin'),
            ),
          ),
          const SizedBox(height: 14),
        ],
        OutlinedButton.icon(
          onPressed: () async {
            String? logoutWarning;
            try {
              await ref.read(authControllerProvider.notifier).logout();
            } on Object catch (error) {
              if (context.mounted) {
                logoutWarning = presentError(context, error);
              }
            }
            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            context.go('/');
            if (logoutWarning != null) {
              messenger.showSnackBar(SnackBar(content: Text(logoutWarning)));
            }
          },
          icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
          label: Text(
            context.l10n.tr('action.logout'),
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}

class _EmailChangeSheet extends ConsumerStatefulWidget {
  const _EmailChangeSheet();
  @override
  ConsumerState<_EmailChangeSheet> createState() => _EmailChangeSheetState();
}

class _EmailChangeSheetState extends ConsumerState<_EmailChangeSheet> {
  final _input = TextEditingController();
  EmailChangeStatusModel? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await ref.read(emailChangeRepositoryProvider).getStatus();
      if (mounted) {
        setState(() {
          _status = value;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = presentError(context, error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _act() async {
    final value = _input.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_status == null) {
        _status = await ref.read(emailChangeRepositoryProvider).start(value);
      } else {
        final response = _status!.currentEmailVerified
            ? await ref.read(emailChangeRepositoryProvider).verifyNew(value)
            : await ref
                  .read(emailChangeRepositoryProvider)
                  .verifyCurrent(value);
        _status = response.status;
        if (response.authentication != null) {
          await ref
              .read(authControllerProvider.notifier)
              .acceptSession(response.authentication!);
        }
        if (response.completed && mounted) {
          ref.invalidate(_profileProvider);
          Navigator.pop(context);
          return;
        }
      }
      _input.clear();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = presentError(context, error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('profile.emailChange'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tr('profile.emailChangeHelp'),
              style: const TextStyle(color: AppColors.ink600),
            ),
            if (status != null) ...[
              const SizedBox(height: 16),
              _VerificationRow(
                label: status.currentEmail,
                verified: status.currentEmailVerified,
              ),
              _VerificationRow(
                label: status.newEmail,
                verified: status.newEmailVerified,
              ),
            ],
            const SizedBox(height: 18),
            if (_loading)
              const AppLoadingView(compact: true)
            else
              TextField(
                controller: _input,
                keyboardType: status == null
                    ? TextInputType.emailAddress
                    : TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: status == null
                      ? context.l10n.tr('profile.newEmail')
                      : context.l10n.tr('auth.code'),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _loading ? null : _act,
              child: Text(context.l10n.tr('action.continue')),
            ),
            if (status != null)
              TextButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await ref.read(emailChangeRepositoryProvider).cancel();
                        if (context.mounted) Navigator.pop(context);
                      },
                child: Text(context.l10n.tr('action.cancel')),
              ),
          ],
        ),
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({required this.label, required this.verified});
  final String label;
  final bool verified;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      verified ? Icons.check_circle_rounded : Icons.schedule_rounded,
      color: verified ? AppColors.success : AppColors.warning,
    ),
    title: Directionality(textDirection: TextDirection.ltr, child: Text(label)),
  );
}
