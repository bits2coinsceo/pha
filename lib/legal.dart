import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'widgets.dart';

/// In-app legal documents shipped as Flutter assets.
enum LegalDocument {
  termsOfService,
  privacyPolicy,
}

extension LegalDocumentX on LegalDocument {
  String get title => switch (this) {
        LegalDocument.termsOfService => 'Terms of Service & Agreement',
        LegalDocument.privacyPolicy => 'Privacy Policy',
      };

  String get shortTitle => switch (this) {
        LegalDocument.termsOfService => 'Agreement',
        LegalDocument.privacyPolicy => 'Privacy Policy',
      };

  String get assetPath => switch (this) {
        LegalDocument.termsOfService =>
          'assets/legal/terms_of_service.txt',
        LegalDocument.privacyPolicy => 'assets/legal/privacy_policy.txt',
      };

  String get pdfAssetPath => switch (this) {
        LegalDocument.termsOfService =>
          'assets/legal/terms_of_service.pdf',
        LegalDocument.privacyPolicy => 'assets/legal/privacy_policy.pdf',
      };
}

Future<String> loadLegalDocumentText(LegalDocument doc) async {
  return rootBundle.loadString(doc.assetPath);
}

/// Full-screen reader for Agreement / Privacy Policy.
class LegalDocumentPage extends StatefulWidget {
  final LegalDocument document;

  const LegalDocumentPage({super.key, required this.document});

  static Future<void> open(BuildContext context, LegalDocument document) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LegalDocumentPage(document: document),
      ),
    );
  }

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  String? _text;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await loadLegalDocumentText(widget.document);
      if (mounted) setState(() => _text = text);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.gray50,
      appBar: AppBar(
        backgroundColor: C.card,
        foregroundColor: C.gray900,
        elevation: 0,
        title: Text(
          widget.document.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: C.gray900,
          ),
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load document.\n$_error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.gray600),
                ),
              ),
            )
          : _text == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: SelectableText(
                          _text!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: C.gray800,
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: PrimaryButton(
                          label: 'Close',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
