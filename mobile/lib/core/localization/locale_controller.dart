import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('SharedPreferences has not been initialized.'),
);

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
      return LocaleController(ref.watch(sharedPreferencesProvider));
    });

class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._preferences)
    : super(
        Locale(
          _preferences.getString(_key) == 'en' ? 'en' : 'fa',
          _preferences.getString(_key) == 'en' ? 'US' : 'IR',
        ),
      );

  static const _key = 'hardware_reserve.locale';
  final SharedPreferences _preferences;

  Future<void> setLanguage(String languageCode) async {
    final normalized = languageCode == 'en' ? 'en' : 'fa';
    state = Locale(normalized, normalized == 'fa' ? 'IR' : 'US');
    await _preferences.setString(_key, normalized);
  }

  Future<void> toggle() =>
      setLanguage(state.languageCode == 'fa' ? 'en' : 'fa');
}
