import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../locale_controller.dart';
import '../theme.dart';
import '../theme_mode.dart';

/// Compact language selector used in onboarding and profile.
class LanguagePicker extends StatelessWidget {
  /// When true, shows a titled card with all options listed.
  final bool expanded;

  const LanguagePicker({super.key, this.expanded = true});

  @override
  Widget build(BuildContext context) {
    // Rebuild in lockstep with dark/light toggle (C.* colors are theme-dependent).
    context.watch<ThemeModeController>();
    final localeCtrl = context.watch<LocaleController>();
    final l10n = context.l10n;

    if (!expanded) {
      return _compactButton(context, localeCtrl, l10n);
    }

    return Container(
      decoration: cardDecoration(radius: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.language, color: C.accentPrimary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.language,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.gray900,
                      ),
                    ),
                    Text(
                      l10n.chooseLanguageSubtitle,
                      style: TextStyle(fontSize: 12, color: C.gray500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _expandedGrid(localeCtrl),
        ],
      ),
    );
  }

  Widget _expandedGrid(LocaleController localeCtrl) {
    final rows = <List<Locale>>[
      LocaleController.supportedLocales.take(3).toList(),
      LocaleController.supportedLocales.skip(3).toList(),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Row(
            children: [
              for (var j = 0; j < rows[i].length; j++) ...[
                Expanded(child: _expandedTile(localeCtrl, rows[i][j])),
                if (j < rows[i].length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          if (i < rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _expandedTile(LocaleController localeCtrl, Locale locale) {
    final selected = localeCtrl.locale.languageCode == locale.languageCode;
    return InkWell(
      onTap: () => localeCtrl.setLocale(locale),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? C.blue50 : C.gray50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? C.blue500 : C.gray200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                LocaleController.nativeName(locale),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                textDirection: locale.languageCode == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? C.blue600 : C.gray800,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 6),
              Icon(Icons.check_circle, color: C.blue500, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _compactButton(
    BuildContext context,
    LocaleController localeCtrl,
    AppLocalizations l10n,
  ) {
    return OutlinedButton.icon(
      onPressed: () => _showSheet(context, localeCtrl, l10n),
      icon: Icon(Icons.language, size: 18, color: C.accentPrimary),
      label: Text(
        LocaleController.nativeName(localeCtrl.locale),
        style: TextStyle(fontWeight: FontWeight.w600, color: C.gray800),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: C.gray200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _showSheet(
    BuildContext context,
    LocaleController localeCtrl,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.chooseLanguage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: C.gray900,
                  ),
                ),
                const SizedBox(height: 12),
                ...LocaleController.supportedLocales.map((locale) {
                  final selected =
                      localeCtrl.locale.languageCode == locale.languageCode;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selected: selected,
                    selectedTileColor: C.blue50,
                    title: Text(
                      LocaleController.nativeName(locale),
                      textDirection: locale.languageCode == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: C.gray900,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check, color: C.blue500)
                        : null,
                    onTap: () async {
                      await localeCtrl.setLocale(locale);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
