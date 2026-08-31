import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pha_flutter/l10n/generated/app_localizations.dart';
import 'package:pha_flutter/locale_controller.dart';

void main() {
  test('supported locales are in product order', () {
    expect(
      LocaleController.supportedLocales.map((l) => l.languageCode).toList(),
      ['en', 'es', 'ru', 'zh', 'ar'],
    );
  });

  testWidgets('all locales resolve AppLocalizations and Arabic is RTL',
      (tester) async {
    for (final locale in LocaleController.supportedLocales) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: LocaleController.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return Text(l10n.navHome);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(l10n.navHome.isNotEmpty, true, reason: '${locale.languageCode} navHome');
      expect(l10n.historyTitle.isNotEmpty, true);
      expect(l10n.chooseLanguage.isNotEmpty, true);
      expect(l10n.actionPhysicalActivity.isNotEmpty, true);

      final direction = Directionality.of(
        tester.element(find.text(l10n.navHome)),
      );
      if (locale.languageCode == 'ar') {
        expect(direction, TextDirection.rtl);
        expect(l10n.navHome, 'الرئيسية');
      } else {
        expect(direction, TextDirection.ltr);
      }
    }

    // Spot-check translations are distinct.
    final en = await _l10nFor(tester, const Locale('en'));
    final es = await _l10nFor(tester, const Locale('es'));
    final ru = await _l10nFor(tester, const Locale('ru'));
    final zh = await _l10nFor(tester, const Locale('zh'));
    final ar = await _l10nFor(tester, const Locale('ar'));

    expect(en.navHome, 'Home');
    expect(es.navHome, 'Inicio');
    expect(ru.navHome, 'Главная');
    expect(zh.navHome, '首页');
    expect(ar.navHome, 'الرئيسية');
    expect({en.navHome, es.navHome, ru.navHome, zh.navHome, ar.navHome}.length, 5);
  });
}

Future<AppLocalizations> _l10nFor(WidgetTester tester, Locale locale) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: LocaleController.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return l10n;
}
