import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../db.dart';
import '../services.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';

const _uuid = Uuid();

Future<int> _count(String table, String userId) async {
  final r = await Db.instance.raw
      .rawQuery('SELECT COUNT(*) c FROM $table WHERE user_id = ?', [userId]);
  return (r.first['c'] as num).toInt();
}

// ── Upload Analysis ──────────────────────────────────────────────────────────
class UploadAnalysisModal extends StatefulWidget {
  final VoidCallback onNeedUpgrade;
  const UploadAnalysisModal({super.key, required this.onNeedUpgrade});

  @override
  State<UploadAnalysisModal> createState() => _UploadAnalysisModalState();
}

class _UploadAnalysisModalState extends State<UploadAnalysisModal> {
  String fileType = 'pdf';
  String? fileName;
  int? fileSize;
  bool uploading = false;
  String error = '';
  bool success = false;
  int? uploadCount;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (!auth.isPlus) {
      _count('analysis_uploads', auth.user!.id).then((c) => setState(() => uploadCount = c));
    }
  }

  bool get atLimit => uploadCount != null && uploadCount! >= 2;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: fileType == 'pdf' ? FileType.custom : FileType.image,
      allowedExtensions: fileType == 'pdf' ? ['pdf'] : null,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        fileName = result.files.first.name;
        fileSize = result.files.first.size;
      });
    }
  }

  Future<void> _upload() async {
    final auth = context.read<AuthProvider>();
    if (fileName == null) return;
    if (atLimit) {
      widget.onNeedUpgrade();
      return;
    }
    setState(() {
      uploading = true;
      error = '';
    });
    try {
      await Db.instance.raw.insert('analysis_uploads', {
        'id': _uuid.v4(),
        'user_id': auth.user!.id,
        'file_path': '${auth.user!.id}/${DateTime.now().millisecondsSinceEpoch}_$fileName',
        'file_type': fileType,
        'uploaded_at': DateTime.now().toUtc().toIso8601String(),
      });
      setState(() {
        success = true;
        fileName = null;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AppModal(
      title: 'Upload Analysis',
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!auth.isPlus && uploadCount != null) ...[
            AppBanner(
              text: atLimit
                  ? 'Upload limit reached. Upgrade to PHA Plus+ for unlimited uploads.'
                  : 'Free plan: $uploadCount/2 uploads used. Max 2 pages per file.',
              bg: atLimit ? C.amber50 : C.blue50,
              border: atLimit ? C.amber200 : C.blue100,
              fg: atLimit ? C.amber700 : C.blue700,
            ),
            const SizedBox(height: 16),
          ],
          if (error.isNotEmpty) ...[
            AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700, icon: Icons.error_outline),
            const SizedBox(height: 16),
          ],
          if (success) ...[
            AppBanner(text: 'File uploaded successfully!', bg: C.green50, border: C.green200, fg: C.teal700),
            const SizedBox(height: 16),
          ],
          const Text('File Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: fileType,
            decoration: appInput(''),
            items: const [
              DropdownMenuItem(value: 'pdf', child: Text('PDF Document')),
              DropdownMenuItem(value: 'photo', child: Text('Photo / Image')),
            ],
            onChanged: atLimit ? null : (v) => setState(() => fileType = v!),
          ),
          const SizedBox(height: 16),
          const Text('Select File',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: atLimit ? null : _pickFile,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: atLimit ? C.gray50 : C.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: atLimit ? C.gray200 : C.gray300),
              ),
              child: Column(
                children: [
                  Icon(Icons.upload_file, size: 32, color: atLimit ? C.gray300 : C.gray400),
                  const SizedBox(height: 12),
                  if (fileName != null) ...[
                    Text(fileName!,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: C.blue600)),
                    Text('${((fileSize ?? 0) / 1024).round()} KB — click to change',
                        style: const TextStyle(fontSize: 12, color: C.gray400)),
                  ] else ...[
                    Text(atLimit ? 'Limit reached' : 'Click to select a file',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: atLimit ? C.gray400 : C.gray700)),
                    Text(
                        atLimit
                            ? 'Upgrade to upload more'
                            : (fileType == 'pdf'
                                ? 'PDF up to 2 pages (free plan)'
                                : 'JPG, PNG, or GIF'),
                        style: const TextStyle(fontSize: 12, color: C.gray400)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          atLimit
              ? PrimaryButton(
                  label: 'Upgrade to PHA Plus+',
                  color: C.amber500,
                  icon: const Icon(Icons.auto_awesome, size: 16, color: C.white),
                  onPressed: widget.onNeedUpgrade,
                )
              : PrimaryButton(
                  label: uploading ? 'Uploading...' : 'Upload File',
                  onPressed: (fileName == null || uploading) ? null : _upload,
                ),
        ],
      ),
    );
  }
}

// ── AI Chat ──────────────────────────────────────────────────────────────────
class _Msg {
  final bool isUser;
  final String text;
  _Msg(this.isUser, this.text);
}

class AIChatModal extends StatefulWidget {
  final VoidCallback onNeedUpgrade;
  const AIChatModal({super.key, required this.onNeedUpgrade});

  @override
  State<AIChatModal> createState() => _AIChatModalState();
}

class _AIChatModalState extends State<AIChatModal> {
  final _messages = <_Msg>[
    _Msg(false,
        "Hello! I'm your AI health assistant. Would you like us to use the data you provided during onboarding? After that, you can describe your problem in detail."),
  ];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool loading = false;
  int? consultCount;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (!auth.isPlus) {
      _count('ai_consultations', auth.user!.id).then((c) => setState(() => consultCount = c));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get atLimit => consultCount != null && consultCount! >= 3;

  Future<void> _send() async {
    final auth = context.read<AuthProvider>();
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (atLimit) {
      widget.onNeedUpgrade();
      return;
    }
    _input.clear();
    setState(() {
      _messages.add(_Msg(true, text));
      loading = true;
    });
    _scrollDown();
    await Future.delayed(const Duration(milliseconds: 600));
    final reply = AiConsultationService.reply(text);
    await AiConsultationService.save(auth.user!.id, text, reply);
    setState(() {
      _messages.add(_Msg(false, reply));
      loading = false;
      if (!auth.isPlus && consultCount != null) consultCount = consultCount! + 1;
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AppModal(
      title: 'AI Health Assistant',
      onClose: () => Navigator.pop(context),
      child: SizedBox(
        height: 400,
        child: Column(
          children: [
            if (!auth.isPlus && consultCount != null) ...[
              AppBanner(
                text: atLimit
                    ? 'Free consultation limit reached.'
                    : '${3 - consultCount!} of 3 free consultations remaining.',
                bg: atLimit ? C.amber50 : C.blue50,
                border: atLimit ? C.amber200 : C.blue100,
                fg: atLimit ? C.amber700 : C.blue600,
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: _messages.length + (loading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) {
                    return _bubble(_Msg(false, '…'));
                  }
                  return _bubble(_messages[i]);
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: C.gray100, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !loading && !atLimit,
                    onSubmitted: (_) => _send(),
                    decoration: appInput(atLimit
                            ? 'Upgrade to continue chatting…'
                            : 'Ask about sleep, exercise, nutrition...')
                        .copyWith(fillColor: C.gray50),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: atLimit ? widget.onNeedUpgrade : _send,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: atLimit ? C.amber500 : C.blue500,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(atLimit ? Icons.auto_awesome : Icons.send,
                        size: 16, color: C.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final avatar = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
          color: m.isUser ? C.blue100 : C.teal100, shape: BoxShape.circle),
      child: Icon(m.isUser ? Icons.person : Icons.smart_toy,
          size: 16, color: m.isUser ? C.blue600 : C.teal600),
    );
    final bubble = Flexible(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: m.isUser ? C.blue500 : C.gray100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(m.text,
            style: TextStyle(
                fontSize: 14, height: 1.4, color: m.isUser ? C.white : C.gray800)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: m.isUser ? [bubble, avatar] : [avatar, bubble],
      ),
    );
  }
}

// ── Wellness Check (Stress Test) ─────────────────────────────────────────────
class StressTestModal extends StatefulWidget {
  const StressTestModal({super.key});

  @override
  State<StressTestModal> createState() => _StressTestModalState();
}

class _StressTestModalState extends State<StressTestModal> {
  static const _questions = [
    ('How stressed do you feel right now?', true),
    ('How well did you sleep last night?', false),
    ('How is your energy level today?', false),
    ('How would you rate your mood?', false),
    ('How is your overall wellbeing?', false),
  ];
  static const _labels = ['Very poor', 'Poor', 'Moderate', 'Good', 'Excellent'];

  int current = 0;
  final answers = <int>[];
  bool showResult = false;
  bool saving = false;

  Future<void> _answer(int raw) async {
    final reverse = _questions[current].$2;
    final score = reverse ? (6 - raw) * 20 : raw * 20;
    answers.add(score);
    if (current < _questions.length - 1) {
      setState(() => current++);
    } else {
      setState(() => saving = true);
      final auth = context.read<AuthProvider>();
      final avg = (answers.reduce((a, b) => a + b) / answers.length).round();
      final result = avg >= 70 ? 'Excellent' : avg >= 50 ? 'Good' : 'Needs attention';
      await Db.instance.raw.insert('stress_tests', {
        'id': _uuid.v4(),
        'user_id': auth.user!.id,
        'score': avg,
        'result': result,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      setState(() {
        showResult = true;
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showResult) {
      final avg = (answers.reduce((a, b) => a + b) / answers.length).round();
      final result = avg >= 70 ? 'Excellent' : avg >= 50 ? 'Good' : 'Needs attention';
      final color = avg >= 70 ? C.green500 : avg >= 50 ? C.yellow500 : C.red500;
      final bg = avg >= 70 ? C.green50 : avg >= 50 ? C.yellow50 : C.red50;
      final border = avg >= 70 ? C.green200 : avg >= 50 ? C.yellow200 : C.red200;
      const desc = {
        'Excellent': 'Great job! Your wellness indicators are strong. Keep up the healthy habits.',
        'Good': 'You are doing well. Small improvements in sleep or stress could push you to excellent.',
        'Needs attention':
            'Consider taking steps to improve your rest, manage stress, or speak to a professional.',
      };
      return AppModal(
        title: 'Wellness Results',
        onClose: () => Navigator.pop(context),
        child: Column(
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: border, width: 4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$avg',
                      style: TextStyle(
                          fontSize: 36, fontWeight: FontWeight.bold, color: color)),
                  const Text('/100', style: TextStyle(fontSize: 12, color: C.gray500)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(result,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: C.gray900)),
            const SizedBox(height: 8),
            Text(desc[result]!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: C.gray500)),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }

    final progress = current / _questions.length;
    return AppModal(
      title: 'Wellness Check',
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${current + 1} of ${_questions.length}',
                  style: const TextStyle(fontSize: 12, color: C.gray500)),
              Text('${(progress * 100).round()}% complete',
                  style: const TextStyle(fontSize: 12, color: C.gray500)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: C.gray100,
              valueColor: const AlwaysStoppedAnimation(C.blue500),
            ),
          ),
          const SizedBox(height: 24),
          Text(_questions[current].$1,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
          const SizedBox(height: 24),
          ...List.generate(5, (i) {
            final score = i + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: saving ? null : () => _answer(score),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.gray200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_labels[i],
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: C.gray800)),
                      Text('$score/5',
                          style: const TextStyle(fontSize: 12, color: C.gray400)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Log Metric ───────────────────────────────────────────────────────────────
class LogMetricModal extends StatefulWidget {
  final VoidCallback onSaved;
  const LogMetricModal({super.key, required this.onSaved});

  @override
  State<LogMetricModal> createState() => _LogMetricModalState();
}

class _LogMetricModalState extends State<LogMetricModal> {
  String metricType = 'steps';
  final _value = TextEditingController();
  final _notes = TextEditingController();
  bool saving = false;
  String error = '';
  bool success = false;

  @override
  void dispose() {
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<({String value, String label, String unit, String hint})> _metrics(bool imp) => [
        (value: 'steps', label: 'Steps', unit: 'steps', hint: 'e.g. 8000'),
        (value: 'calories', label: 'Calories', unit: 'kcal', hint: 'e.g. 350'),
        (value: 'distance', label: 'Distance', unit: imp ? 'miles' : 'km', hint: imp ? 'e.g. 3.2' : 'e.g. 5.2'),
        (value: 'active_time', label: 'Active Time', unit: 'min', hint: 'e.g. 45'),
        (value: 'weight', label: 'Weight', unit: imp ? 'lbs' : 'kg', hint: imp ? 'e.g. 165' : 'e.g. 72.5'),
        (value: 'glucose', label: 'Blood Glucose', unit: imp ? 'mg/dL' : 'mmol/L', hint: imp ? 'e.g. 95' : 'e.g. 5.3'),
        (value: 'water', label: 'Water Intake', unit: 'ml', hint: 'e.g. 2000'),
      ];

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final num = double.tryParse(_value.text);
    if (num == null || num < 0) {
      setState(() => error = 'Please enter a valid positive number.');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    final now = DateTime.now().toUtc().toIso8601String();
    await Db.instance.raw.insert('health_metrics', {
      'id': _uuid.v4(),
      'user_id': auth.user!.id,
      'metric_type': metricType,
      'value': toStorageValue(metricType, num, auth.unitSystem),
      'recorded_at': now,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'created_at': now,
    });
    setState(() {
      success = true;
      saving = false;
    });
    widget.onSaved();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final imp = context.watch<AuthProvider>().unitSystem == 'imperial';
    final metrics = _metrics(imp);
    final selected = metrics.firstWhere((m) => m.value == metricType);
    return AppModal(
      title: 'Log Health Metric',
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error.isNotEmpty) ...[
            AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700, icon: Icons.error_outline),
            const SizedBox(height: 16),
          ],
          if (success) ...[
            AppBanner(text: 'Metric saved!', bg: C.green50, border: C.green200, fg: C.teal700),
            const SizedBox(height: 16),
          ],
          const Text('Metric Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: metricType,
            decoration: appInput(''),
            items: metrics
                .map((m) => DropdownMenuItem(value: m.value, child: Text('${m.label} (${m.unit})')))
                .toList(),
            onChanged: (v) => setState(() {
              metricType = v!;
              _value.clear();
            }),
          ),
          const SizedBox(height: 16),
          Text('Value  (${selected.unit})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          const SizedBox(height: 8),
          TextField(controller: _value, decoration: appInput(selected.hint)),
          const SizedBox(height: 16),
          const Text('Notes  (optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          const SizedBox(height: 8),
          TextField(controller: _notes, decoration: appInput('Any additional notes...')),
          const SizedBox(height: 16),
          PrimaryButton(
            label: saving ? 'Saving...' : 'Save Metric',
            onPressed: (_value.text.isEmpty || saving) ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ── Upgrade ──────────────────────────────────────────────────────────────────
class UpgradeModal extends StatefulWidget {
  const UpgradeModal({super.key});

  @override
  State<UpgradeModal> createState() => _UpgradeModalState();
}

class _UpgradeModalState extends State<UpgradeModal> {
  String? loadingPlan;
  bool done = false;

  Future<void> _upgrade(String plan) async {
    setState(() => loadingPlan = plan);
    await context.read<AuthProvider>().upgradeToPlus(plan);
    setState(() {
      done = true;
      loadingPlan = null;
    });
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isPlus = context.watch<AuthProvider>().isPlus;
    if (isPlus || done) {
      return AppModal(
        title: '',
        onClose: () => Navigator.pop(context),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: C.amber50, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: C.amber500, size: 32),
            ),
            const SizedBox(height: 16),
            const Text("You're on PHA Plus+!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: C.gray900)),
            const SizedBox(height: 8),
            const Text(
                'All features are now unlocked. Enjoy unlimited uploads and the PsychoTest.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: C.gray500)),
          ],
        ),
      );
    }

    const features = [
      ('Analysis Uploads', '2 files', 'Unlimited'),
      ('Pages per File', '2 pages', 'Unlimited'),
      ('PsychoTest', 'Locked', 'Full access'),
      ('AI Consultation', 'Included', 'Included'),
      ('Wellness Check', 'Included', 'Included'),
    ];

    return AppModal(
      title: '',
      onClose: () => Navigator.pop(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(gradient: kAmberGradient, borderRadius: BorderRadius.circular(99)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.auto_awesome, size: 16, color: C.white),
                SizedBox(width: 8),
                Text('PHA Plus+',
                    style: TextStyle(color: C.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Unlock All Features',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
          const SizedBox(height: 8),
          const Text('Get the full power of your Personal Health Assistant',
              style: TextStyle(fontSize: 14, color: C.gray500)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.gray100),
            ),
            child: Column(
              children: [
                Container(
                  color: C.gray50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Text('FEATURE', style: _thStyle)),
                      Expanded(child: Text('FREE', textAlign: TextAlign.center, style: _thStyle)),
                      Expanded(
                          child: Text('PLUS+',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: C.amber600))),
                    ],
                  ),
                ),
                ...features.map((f) => Container(
                      decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: C.gray100))),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text(f.$1,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: C.gray700))),
                          Expanded(
                              child: Text(f.$2,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14, color: C.gray400))),
                          Expanded(
                              child: Text(f.$3,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: C.emerald600))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _planCard(
                    plan: 'monthly',
                    name: 'Monthly',
                    price: '\$9.99',
                    per: '/mo',
                    note: 'Billed monthly.',
                    best: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _planCard(
                    plan: 'semiannual',
                    name: '6 Months',
                    price: '\$49.99',
                    per: '/6mo',
                    note: 'Save ~17%.',
                    best: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _planCard(
                    plan: 'annual',
                    name: 'Annual',
                    price: '\$69.99',
                    per: '/yr',
                    note: 'Save ~42%.',
                    best: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.teal50, C.blue50]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.teal100),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(color: C.teal100, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.psychology, color: C.teal600, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('PsychoTest — Stress & Psychosomatic Assessment',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: C.gray900)),
                      SizedBox(height: 2),
                      Text(
                          'In-depth self-assessment for stress levels, psychosomatic patterns, and mental wellness indicators.',
                          style: TextStyle(fontSize: 12, color: C.gray500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _thStyle =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.gray500);

  Widget _planCard({
    required String plan,
    required String name,
    required String price,
    required String per,
    required String note,
    required bool best,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: best ? C.amber50 : C.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: best ? C.amber400 : C.gray200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 18,
            child: best
                ? Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: C.amber400, borderRadius: BorderRadius.circular(99)),
                    child: const Text('BEST',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.bold, color: C.white)),
                  )
                : null,
          ),
          Text(name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: best ? C.amber600 : C.gray500)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(price,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: C.gray900)),
                Text(per, style: const TextStyle(fontSize: 10, color: C.gray400)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: C.gray400, height: 1.2)),
          const Spacer(),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: loadingPlan != null ? null : () => _upgrade(plan),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration:
                  BoxDecoration(gradient: kAmberGradient, borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: loadingPlan == plan
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: C.white),
                      )
                    : const Icon(Icons.auto_awesome, size: 14, color: C.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
