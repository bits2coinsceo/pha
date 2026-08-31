import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/generated/app_localizations.dart';

/// Persists and applies the app UI language.
class LocaleController extends ChangeNotifier {
  static const _prefKey = 'app_locale';

  /// Exact order required by product: EN → ES → RU → ZH → AR.
  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('ru'),
    Locale('zh'),
    Locale('ar'),
  ];

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  bool get isRtl => _locale.languageCode == 'ar';

  static String nativeName(Locale locale) {
    switch (locale.languageCode) {
      case 'es':
        return 'Español';
      case 'ru':
        return 'Русский';
      case 'zh':
        return '普通话';
      case 'ar':
        return 'العربية';
      case 'en':
      default:
        return 'English';
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code != null) {
      for (final locale in supportedLocales) {
        if (locale.languageCode == code) {
          _locale = locale;
          break;
        }
      }
    }
    notifyListeners();
  }

  /// Full language name for AI prompt instructions.
  static String languageName(String code) {
    switch (code) {
      case 'es': return 'Spanish';
      case 'ru': return 'Russian';
      case 'zh': return 'Chinese';
      case 'ar': return 'Arabic';
      case 'en':
      default: return 'English';
    }
  }

  /// Prompt block telling Gemini which language the app UI uses.
  /// Always returned (including English) so replies follow the app locale, not
  /// the language of uploaded labs, chat history, or the patient's message.
  static Future<String> aiLanguageInstruction() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey) ?? 'en';
    final name = languageName(code);
    return 'CRITICAL — APP UI LANGUAGE: The patient\'s PHA app is set to $name. '
        'Write your ENTIRE response in $name only. '
        'Do NOT switch language because of uploaded document text (e.g. Romanian or '
        'Latin lab labels), because of earlier chat history in another language, '
        'or because the patient typed in another language. '
        'You may quote original test names/abbreviations from a document, but every '
        'explanation, recommendation, heading, and bullet must be in $name.\n\n';
  }

  /// Load [AppLocalizations] for the persisted locale (no [BuildContext]).
  static Future<AppLocalizations> loadLocalizations() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey) ?? 'en';
    return lookupAppLocalizations(Locale(code));
  }

  Future<void> setLocale(Locale locale) async {
    final supported = supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    );
    if (!supported) return;
    if (_locale.languageCode == locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _locale.languageCode);
    notifyListeners();
  }
}
