import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../api.dart';
import '../auth.dart';
import '../daily_metric_store.dart';
import '../daily_vitals.dart';
import '../db.dart';
import '../health_index.dart';
import '../image_compress.dart';
import '../medical_guidelines.dart';
import '../meal_calories.dart';
import '../onboarding_hp.dart';
import '../physical_activity.dart';
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
  final void Function(String analysis, String fileName) onAnalysisDelivered;
  const UploadAnalysisModal({
    super.key,
    required this.onNeedUpgrade,
    required this.onAnalysisDelivered,
  });

  @override
  State<UploadAnalysisModal> createState() => _UploadAnalysisModalState();
}

class _UploadAnalysisModalState extends State<UploadAnalysisModal> {
  String fileType = 'pdf';
  String? fileName;
  String? filePath;
  int? fileSize;
  bool uploading = false;
  String error = '';
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
        filePath = result.files.first.path;
        fileSize = result.files.first.size;
      });
    }
  }

  Future<void> _upload() async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasFreeAccess) {
      widget.onNeedUpgrade();
      return;
    }
    if (fileName == null) return;
    if (atLimit) {
      widget.onNeedUpgrade();
      return;
    }
    if (filePath == null) {
      setState(() => error = 'Could not read the selected file. Please pick it again.');
      return;
    }
    setState(() {
      uploading = true;
      error = '';
    });
    final uploadedName = fileName!;
    try {
      final textLogs =
          await AiConsultationService.buildFullPatientContext(auth.user!.id);
      final uploadPath = fileType == 'pdf'
          ? filePath!
          : await compressImageForUpload(
              filePath!,
              quality: 60,
              maxWidth: 800,
              maxHeight: 800,
            );
      final analysis = await ApiClient.analyze(
        userId: auth.user!.id,
        filePath: uploadPath,
        textLogs: textLogs,
      );
      await Db.instance.raw.insert('analysis_uploads', {
        'id': _uuid.v4(),
        'user_id': auth.user!.id,
        'file_path':
            '${auth.user!.id}/${DateTime.now().millisecondsSinceEpoch}_$uploadedName',
        'file_type': fileType,
        'analysis': analysis,
        'uploaded_at': DateTime.now().toUtc().toIso8601String(),
      });
      await AiConsultationService.recordAnalysisInChat(
        auth.user!.id,
        fileName: uploadedName,
        analysis: analysis,
      );
      await auth.syncPatientHistory();
      if (!auth.isPlus && uploadCount != null) {
        uploadCount = uploadCount! + 1;
      }
      if (!mounted) return;
      widget.onAnalysisDelivered(analysis, uploadedName);
    } on ApiException catch (e) {
      setState(() => error = e.userFacingMessage);
    } catch (e) {
      setState(() => error = 'Upload failed. Please try again.');
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
            SizedBox(height: 16),
          ],
          if (error.isNotEmpty) ...[
            AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700, icon: Icons.error_outline),
            SizedBox(height: 16),
          ],
          if (uploading) ...[
            AppBanner(
              text: 'Analyzing your file with Ai Doc…',
              bg: C.blue50,
              border: C.blue100,
              fg: C.blue700,
            ),
            SizedBox(height: 16),
          ],
          Text('File Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: fileType,
            decoration: appInput(''),
            items: const [
              DropdownMenuItem(value: 'pdf', child: Text('PDF Document')),
              DropdownMenuItem(value: 'photo', child: Text('Photo / Image')),
            ],
            onChanged: atLimit ? null : (v) => setState(() => fileType = v!),
          ),
          SizedBox(height: 16),
          Text('Select File',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
          GestureDetector(
            onTap: atLimit ? null : _pickFile,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: C.gray100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.gray200),
              ),
              child: Column(
                children: [
                  Icon(Icons.upload_file, size: 32, color: atLimit ? C.gray300 : C.gray400),
                  SizedBox(height: 12),
                  if (fileName != null) ...[
                    Text(fileName!,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: C.gray900)),
                    Text('${((fileSize ?? 0) / 1024).round()} KB — click to change',
                        style: TextStyle(fontSize: 12, color: C.gray400)),
                  ] else ...[
                    Text(atLimit ? 'Limit reached' : 'Click to select a file',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: atLimit ? C.gray400 : C.gray600)),
                    Text(
                        atLimit
                            ? 'Upgrade to upload more'
                            : (fileType == 'pdf'
                                ? 'PDF up to 2 pages (free plan)'
                                : 'JPG, PNG, or GIF'),
                        style: TextStyle(fontSize: 12, color: C.gray400)),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          atLimit
              ? PrimaryButton(
                  label: 'Upgrade to PHA Plus+',
                  color: C.amber500,
                  icon: Icon(Icons.auto_awesome, size: 16, color: C.white),
                  onPressed: widget.onNeedUpgrade,
                )
              : PrimaryButton(
                  label: uploading ? 'Analyzing...' : 'Upload File',
                  onPressed: (fileName == null || uploading) ? null : _upload,
                ),
        ],
      ),
    );
  }
}

// ── Check Meal Calories ──────────────────────────────────────────────────────
class CheckMealCaloriesModal extends StatefulWidget {
  final VoidCallback onNeedUpgrade;
  const CheckMealCaloriesModal({super.key, required this.onNeedUpgrade});

  @override
  State<CheckMealCaloriesModal> createState() => _CheckMealCaloriesModalState();
}

class _CheckMealCaloriesModalState extends State<CheckMealCaloriesModal> {
  final _picker = ImagePicker();
  String? fileName;
  String? filePath;
  bool analyzing = false;
  bool confirming = false;
  String error = '';
  MealCalorieResult? pendingResult;
  bool savedToast = false;
  int? checksLast24h;
  DailyMealSummary? todaySummary;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _loadToday();
  }

  Future<void> _refreshCount() async {
    final auth = context.read<AuthProvider>();
    if (auth.isPlus) return;
    final count = await MealCalorieService.countLast24Hours(auth.user!.id);
    if (mounted) setState(() => checksLast24h = count);
  }

  Future<void> _loadToday() async {
    final auth = context.read<AuthProvider>();
    final summary =
        await MealCalorieService.summaryForDay(auth.user!.id, DateTime.now());
    if (mounted) setState(() => todaySummary = summary);
  }

  bool _isAtLimit(AuthProvider auth) =>
      !auth.isPlus &&
      checksLast24h != null &&
      checksLast24h! >= MealCalorieService.freeDailyLimit;

  Future<void> _pickImage(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    if (_isAtLimit(auth)) {
      widget.onNeedUpgrade();
      return;
    }
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 60,
    );
    if (picked == null) return;
    setState(() {
      fileName = picked.name;
      filePath = picked.path;
      pendingResult = null;
      savedToast = false;
      error = '';
    });
  }

  Future<void> _analyze() async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasFreeAccess) {
      widget.onNeedUpgrade();
      return;
    }
    if (filePath == null) return;
    if (_isAtLimit(auth)) {
      widget.onNeedUpgrade();
      return;
    }
    setState(() {
      analyzing = true;
      error = '';
      savedToast = false;
    });
    try {
      final analysis = await MealCalorieService.analyzePhoto(
        userId: auth.user!.id,
        filePath: filePath!,
      );
      if (!mounted) return;
      setState(() {
        pendingResult = analysis;
      });
    } on ApiException catch (e) {
      setState(() => error = e.userFacingMessage);
    } catch (e) {
      setState(() => error = 'Analysis failed. Please try again.');
    } finally {
      if (mounted) setState(() => analyzing = false);
    }
  }

  Future<void> _confirmEaten() async {
    final auth = context.read<AuthProvider>();
    final result = pendingResult;
    if (result == null || filePath == null || confirming) return;
    setState(() => confirming = true);
    try {
      final storedPath =
          '${auth.user!.id}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await MealCalorieService.confirmEaten(
        userId: auth.user!.id,
        filePath: storedPath,
        result: result,
      );
      await auth.syncPatientHistory();
      if (!mounted) return;
      setState(() {
        pendingResult = null;
        fileName = null;
        filePath = null;
        savedToast = true;
        confirming = false;
      });
      await _refreshCount();
      await _loadToday();
    } catch (e) {
      if (mounted) {
        setState(() {
          confirming = false;
          error = 'Could not save meal: $e';
        });
      }
    }
  }

  void _discardPending() {
    setState(() {
      pendingResult = null;
      fileName = null;
      filePath = null;
      savedToast = false;
    });
  }

  ({Color bg, Color border, Color fg}) _categoryColors(MealCalorieCategory cat) {
    return switch (cat) {
      MealCalorieCategory.excellent =>
        (bg: C.green50, border: C.green200, fg: C.teal700),
      MealCalorieCategory.satisfactory =>
        (bg: C.amber50, border: C.amber200, fg: C.amber700),
      MealCalorieCategory.attention =>
        (bg: C.red50, border: C.red200, fg: C.red700),
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final atLimit = _isAtLimit(auth);
    final pending = pendingResult;

    return AppModal(
      title: 'Check Meal Calories',
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!auth.isPlus && checksLast24h != null) ...[
            AppBanner(
              text: atLimit
                  ? 'Free limit reached (2 meals per 24h). Upgrade to PHA Plus+ for unlimited meal checks.'
                  : 'Free plan: $checksLast24h/${MealCalorieService.freeDailyLimit} meals logged in the last 24 hours.',
              bg: atLimit ? C.amber50 : C.blue50,
              border: atLimit ? C.amber200 : C.blue100,
              fg: atLimit ? C.amber700 : C.blue700,
            ),
            const SizedBox(height: 16),
          ],
          if (error.isNotEmpty) ...[
            AppBanner(
              text: error,
              bg: C.red50,
              border: C.red200,
              fg: C.red700,
              icon: Icons.error_outline,
            ),
            const SizedBox(height: 16),
          ],
          if (savedToast) ...[
            AppBanner(
              text: 'Meal logged — counted in today’s intake & Health Index.',
              bg: C.green50,
              border: C.green200,
              fg: C.teal700,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 16),
          ],
          if (analyzing) ...[
            AppBanner(
              text: 'Analyzing your meal…',
              bg: C.blue50,
              border: C.blue100,
              fg: C.blue700,
            ),
            const SizedBox(height: 16),
          ],

          // Pending confirmation card (reference: dish card + check)
          if (pending != null && filePath != null) ...[
            _MealResultCard(
              imagePath: filePath!,
              result: pending,
              confirming: confirming,
              onConfirm: _confirmEaten,
              onDiscard: _discardPending,
              colors: _categoryColors(pending.category),
            ),
            const SizedBox(height: 20),
          ],

          // Capture controls (hidden while pending confirm)
          if (pending == null) ...[
            Text(
              'Take or upload a photo of your meal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: C.gray700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'After analysis, tap ✓ only if you ate this dish — it adds to today’s calories.',
              style: TextStyle(fontSize: 12, color: C.gray500, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        analyzing || atLimit ? null : () => _pickImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt_outlined, color: C.gray600),
                    label: Text('Camera', style: TextStyle(color: C.gray700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        analyzing || atLimit ? null : () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library_outlined, color: C.gray600),
                    label: Text('Gallery', style: TextStyle(color: C.gray700)),
                  ),
                ),
              ],
            ),
            if (fileName != null) ...[
              const SizedBox(height: 12),
              Text(
                fileName!,
                style: TextStyle(fontSize: 13, color: C.gray600),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            atLimit
                ? PrimaryButton(
                    label: 'Upgrade to PHA Plus+',
                    color: C.amber500,
                    icon: Icon(Icons.auto_awesome, size: 16, color: C.white),
                    onPressed: widget.onNeedUpgrade,
                  )
                : PrimaryButton(
                    label: analyzing ? 'Analyzing…' : 'Analyze Meal',
                    onPressed: (filePath == null || analyzing) ? null : _analyze,
                  ),
            const SizedBox(height: 24),
          ],

          // Today’s intake summary (reference: total + list)
          if (todaySummary != null) ...[
            _TodayIntakeSection(summary: todaySummary!),
          ],
        ],
      ),
    );
  }
}

class _MealResultCard extends StatelessWidget {
  final String imagePath;
  final MealCalorieResult result;
  final bool confirming;
  final VoidCallback onConfirm;
  final VoidCallback onDiscard;
  final ({Color bg, Color border, Color fg}) colors;

  const _MealResultCard({
    required this.imagePath,
    required this.result,
    required this.confirming,
    required this.onConfirm,
    required this.onDiscard,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(imagePath),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 72,
                    height: 72,
                    color: C.gray100,
                    child: Icon(Icons.restaurant, color: C.gray400),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.mealName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: C.gray900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(${result.portion})',
                      style: TextStyle(fontSize: 13, color: C.gray500),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        result.categoryLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.local_fire_department, size: 20, color: C.orange500),
              const SizedBox(width: 4),
              Text(
                result.calories != null ? '${result.calories} cal' : '— cal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: C.gray900,
                ),
              ),
              if (result.proteinG != null ||
                  result.carbsG != null ||
                  result.fatG != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [
                      if (result.proteinG != null)
                        'P ${result.proteinG!.toStringAsFixed(0)}g',
                      if (result.carbsG != null)
                        'C ${result.carbsG!.toStringAsFixed(0)}g',
                      if (result.fatG != null)
                        'F ${result.fatG!.toStringAsFixed(0)}g',
                    ].join(' · '),
                    style: TextStyle(fontSize: 11, color: C.gray500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              Material(
                color: C.teal600,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: confirming ? null : onConfirm,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: confirming
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tap ✓ to confirm you ate this — adds to today’s intake.',
            style: TextStyle(fontSize: 12, color: C.gray500, height: 1.35),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: confirming ? null : onDiscard,
            child: Text(
              'Discard',
              style: TextStyle(fontSize: 13, color: C.gray500),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayIntakeSection extends StatelessWidget {
  final DailyMealSummary summary;
  const _TodayIntakeSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total Intake',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: C.gray500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${summary.totalCalories} cal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: C.gray900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${summary.qualityLabel} · target ~${summary.targetCalories} kcal',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: C.gray500),
        ),
        const SizedBox(height: 6),
        Text(
          summary.qualityHint,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: C.gray600, height: 1.35),
        ),
        if (summary.proteinG > 0 ||
            summary.carbsG > 0 ||
            summary.fatG > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MacroChip(
                  label: 'Carb',
                  value: '${summary.carbsG.toStringAsFixed(0)}g',
                  color: C.amber500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroChip(
                  label: 'Proteins',
                  value: '${summary.proteinG.toStringAsFixed(0)}g',
                  color: C.teal600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroChip(
                  label: 'Fat',
                  value: '${summary.fatG.toStringAsFixed(0)}g',
                  color: C.orange500,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        if (!summary.hasMeals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No meals confirmed today yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: C.gray400),
            ),
          )
        else
          for (final meal in summary.meals.reversed) ...[
            _LoggedMealRow(meal: meal),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: C.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.gray200),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: C.gray500)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggedMealRow extends StatelessWidget {
  final MealLogEntry meal;
  const _LoggedMealRow({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: C.gray100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.restaurant, color: C.gray400, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.mealName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: C.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '(${meal.portion})',
                  style: TextStyle(fontSize: 12, color: C.gray500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 14, color: C.orange500),
                    const SizedBox(width: 2),
                    Text(
                      meal.calories != null ? '${meal.calories} cal' : '— cal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: C.gray700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: C.teal600.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C.teal600.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.check, color: C.teal600, size: 20),
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
  final String? imagePath;
  _Msg(this.isUser, this.text, {this.imagePath});
}

class AIChatModal extends StatefulWidget {
  final VoidCallback onNeedUpgrade;
  final List<AiChatSeedMessage>? seedMessages;
  const AIChatModal({
    super.key,
    required this.onNeedUpgrade,
    this.seedMessages,
  });

  @override
  State<AIChatModal> createState() => _AIChatModalState();
}

class _AIChatModalState extends State<AIChatModal> {
  final _messages = <_Msg>[
    _Msg(false,
        "Hello! I'm your Ai Doc Assistant. Would you like us to use the data you provided during onboarding? After that, you can describe your problem in detail — or share a photo of a meal, lab result, or anything health-related."),
  ];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  bool loading = false;
  bool _analyzingOnboarding = false;
  bool _awaitingOnboardingConsent = true;
  int? consultCount;

  @override
  void initState() {
    super.initState();
    _loadConsultationHistory();
    final auth = context.read<AuthProvider>();
    if (!auth.isPlus) {
      _count('ai_consultations', auth.user!.id).then((c) => setState(() => consultCount = c));
    }
  }

  Future<void> _loadConsultationHistory() async {
    final auth = context.read<AuthProvider>();
    final rows = await Db.instance.raw.query(
      'ai_consultations',
      where: 'user_id = ?',
      whereArgs: [auth.user!.id],
      orderBy: 'created_at ASC',
      limit: 50,
    );
    if (!mounted) return;
    setState(() {
      for (final r in rows) {
        _messages.add(_Msg(true, r['message'] as String));
        _messages.add(_Msg(false, r['response'] as String));
      }
      final seeds = widget.seedMessages;
      if (seeds != null) {
        for (final m in seeds) {
          _messages.add(_Msg(m.isUser, m.text));
        }
      }
    });
    if (rows.isNotEmpty || widget.seedMessages != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get atLimit => consultCount != null && consultCount! >= 3;

  Future<void> _pickPhoto(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasFreeAccess) {
      widget.onNeedUpgrade();
      return;
    }
    if (atLimit || loading) {
      if (atLimit) widget.onNeedUpgrade();
      return;
    }
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 60,
    );
    if (picked == null || !mounted) return;
    await _send(imagePath: picked.path);
  }

  Future<void> _send({String? imagePath}) async {
    final auth = context.read<AuthProvider>();
    final text = _input.text.trim();
    if (text.isEmpty && imagePath == null) return;
    if (!auth.hasFreeAccess) {
      widget.onNeedUpgrade();
      return;
    }
    if (atLimit) {
      widget.onNeedUpgrade();
      return;
    }

    final useOnboardingData = imagePath == null &&
        _awaitingOnboardingConsent &&
        AiConsultationService.isAffirmativeConsent(text);
    final declinedOnboarding = imagePath == null &&
        _awaitingOnboardingConsent &&
        AiConsultationService.isNegativeConsent(text);
    if (_awaitingOnboardingConsent && imagePath == null) {
      _awaitingOnboardingConsent = false;
    }

    _input.clear();
    _analyzingOnboarding = useOnboardingData;
    final userLabel = imagePath != null
        ? (text.isEmpty ? '📷 Photo' : '📷 $text')
        : text;
    setState(() {
      _messages.add(_Msg(true, userLabel, imagePath: imagePath));
      loading = true;
    });
    _scrollDown();

    String reply;
    try {
      if (imagePath != null) {
        reply = await AiConsultationService.replyWithPhoto(
          userId: auth.user!.id,
          filePath: imagePath,
          caption: text,
        );
      } else if (declinedOnboarding) {
        reply =
            "No problem! Whenever you're ready, describe your symptoms or health concerns in detail — or share a photo.";
      } else if (useOnboardingData) {
        reply = await AiConsultationService.diagnoseFromOnboarding(auth.user!.id);
      } else {
        reply = await AiConsultationService.reply(auth.user!.id, text);
      }
    } on ApiException catch (e) {
      reply = e.userFacingMessage;
    }
    await AiConsultationService.save(auth.user!.id, userLabel, reply);
    await auth.syncPatientHistory();
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg(false, reply));
      loading = false;
      _analyzingOnboarding = false;
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
    return Scaffold(
      backgroundColor: C.gray50,
      appBar: AppBar(
        backgroundColor: C.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: C.gray600),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ai Doc Assistant',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: C.gray900,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            color: C.cardBorder.withValues(alpha: 0.35),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              if (ApiConfig.apiKey.isEmpty) ...[
                AppBanner(
                  text:
                      'Ai Doc is offline — API key not set. Copy dart_define.example.json to dart_define.json, add PHA_API_KEY, then run just reinstall.',
                  bg: C.amber50,
                  border: C.amber200,
                  fg: C.amber700,
                  icon: Icons.warning_amber_rounded,
                ),
                SizedBox(height: 12),
              ],
              if (!auth.isPlus && consultCount != null) ...[
                AppBanner(
                  text: atLimit
                      ? 'Free consultation limit reached.'
                      : '${3 - consultCount!} of 3 free consultations remaining.',
                  bg: atLimit ? C.amber50 : C.blue50,
                  border: atLimit ? C.amber200 : C.blue100,
                  fg: atLimit ? C.amber700 : C.blue600,
                ),
                SizedBox(height: 12),
              ],
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: _messages.length + (loading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i < 0) return const SizedBox.shrink();
                    if (i == _messages.length) {
                      return _bubble(
                        _Msg(
                          false,
                          loading
                              ? (_analyzingOnboarding
                                  ? 'Analyzing your health data…'
                                  : 'Looking at that…')
                              : '…',
                        ),
                      );
                    }
                    if (i >= _messages.length) return const SizedBox.shrink();
                    return _bubble(_messages[i]);
                  },
                ),
              ),
              SizedBox(height: 8),
              Divider(color: C.gray100, height: 1),
              SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Camera',
                    onPressed: (loading || atLimit)
                        ? null
                        : () => _pickPhoto(ImageSource.camera),
                    icon: Icon(Icons.photo_camera_outlined,
                        color: (loading || atLimit) ? C.gray300 : C.blue600),
                  ),
                  IconButton(
                    tooltip: 'Gallery',
                    onPressed: (loading || atLimit)
                        ? null
                        : () => _pickPhoto(ImageSource.gallery),
                    icon: Icon(Icons.photo_library_outlined,
                        color: (loading || atLimit) ? C.gray300 : C.blue600),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !loading && !atLimit,
                      onSubmitted: (_) => _send(),
                      decoration: appInput(atLimit
                              ? 'Upgrade to continue chatting…'
                              : 'Ask about symptoms, or add a photo note')
                          .copyWith(fillColor: C.gray50),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: atLimit ? widget.onNeedUpgrade : () => _send(),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(m.imagePath!),
                  height: 160,
                  width: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) => Text(
                    'Photo',
                    style: TextStyle(
                      color: m.isUser ? C.white : C.gray600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (m.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (m.text.isNotEmpty)
              Text(
                m.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: m.isUser ? C.white : C.gray800,
                ),
              ),
          ],
        ),
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
    if (current < 0 || current >= _questions.length) return;
    final reverse = _questions[current].$2;
    final score = reverse ? (6 - raw) * 20 : raw * 20;
    answers.add(score);
    if (current < _questions.length - 1) {
      setState(() => current++);
    } else {
      setState(() => saving = true);
      final auth = context.read<AuthProvider>();
      final avg = (answers.fold<int>(0, (a, b) => a + b) / answers.length).round();
      final result = WellnessGuidelines.resultLabel(avg);
      await Db.instance.raw.insert('stress_tests', {
        'id': _uuid.v4(),
        'user_id': auth.user!.id,
        'score': avg,
        'result': result,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await HealthIndexService.recalculate(auth.user!.id);
      setState(() {
        showResult = true;
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showResult) {
      final avg = (answers.fold<int>(0, (a, b) => a + b) / answers.length).round();
      final med = WellnessGuidelines.classify(avg);
      final result = WellnessGuidelines.resultLabel(avg);
      final color = switch (med.status) {
        'good' => C.green500,
        'info' => C.blue500,
        'warning' => C.yellow500,
        _ => C.red500,
      };
      final bg = switch (med.status) {
        'good' => C.green50,
        'info' => C.blue50,
        'warning' => C.yellow50,
        _ => C.red50,
      };
      final border = switch (med.status) {
        'good' => C.green200,
        'info' => C.blue200,
        'warning' => C.yellow200,
        _ => C.red200,
      };
      final descText = WellnessGuidelines.resultDescription(avg);
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
                  Text('/100', style: TextStyle(fontSize: 12, color: C.gray500)),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(result,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: C.gray900)),
            SizedBox(height: 8),
            Text(descText,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: C.gray500)),
            SizedBox(height: 20),
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
                  style: TextStyle(fontSize: 12, color: C.gray500)),
              Text('${(progress * 100).round()}% complete',
                  style: TextStyle(fontSize: 12, color: C.gray500)),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: C.gray100,
              valueColor: AlwaysStoppedAnimation(C.blue500),
            ),
          ),
          SizedBox(height: 24),
          Text(
              (current >= 0 && current < _questions.length)
                  ? _questions[current].$1
                  : 'Question unavailable',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
          SizedBox(height: 24),
          ...List.generate(5, (i) {
            if (i < 0 || i >= _labels.length) return const SizedBox.shrink();
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
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: C.gray800)),
                      Text('$score/5',
                          style: TextStyle(fontSize: 12, color: C.gray400)),
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

// ── Bad habits check ─────────────────────────────────────────────────────────
class BadHabitsModal extends StatefulWidget {
  const BadHabitsModal({super.key});

  @override
  State<BadHabitsModal> createState() => _BadHabitsModalState();
}

class _BadHabitsModalState extends State<BadHabitsModal> {
  static const _smokingLevels = [
    ('less_than_one_pack', 'Less than one pack a day'),
    ('one_pack', '1 pack a day'),
    ('more_than_one_pack', 'More than one pack a day'),
  ];

  static const _alcoholLevels = [
    (
      'occasionally',
      'Occasionally — less than 100 g strong alcohol, 1–2 glasses of wine, or up to 2 cans of beer per week',
    ),
    (
      'regularly',
      'Regularly — 200–300 g strong alcohol, 1–2 bottles of wine, or more than 2 L beer per week',
    ),
    (
      'heavy',
      'I get drunk 1–2 times a week to the point of memory loss',
    ),
  ];

  static const _socialMediaLevels = [
    ('rarely', 'Rarely or never'),
    ('under_hour', 'Less than 1 hour a day'),
    ('one_to_two_hours', 'About 1–2 hours a day'),
    ('constantly', 'I constantly surf in my free time'),
  ];

  _BadHabitsStep step = _BadHabitsStep.smoking;
  bool? smokes;
  String? smokingLevel;
  bool? drinksAlcohol;
  String? alcoholLevel;
  String? socialMediaLevel;
  bool saving = false;

  int get _stepIndex {
    switch (step) {
      case _BadHabitsStep.smoking:
        return 0;
      case _BadHabitsStep.smokingLevel:
        return 1;
      case _BadHabitsStep.alcohol:
        return smokes == true ? 2 : 1;
      case _BadHabitsStep.alcoholLevel:
        return smokes == true ? 3 : 2;
      case _BadHabitsStep.socialMedia:
        if (smokes == true && drinksAlcohol == true) return 4;
        if (smokes == true || drinksAlcohol == true) return 3;
        return 2;
      case _BadHabitsStep.done:
        return _totalSteps;
    }
  }

  int get _totalSteps {
    var n = 3; // smoking yes/no, alcohol yes/no, social media
    if (smokes == true) n++;
    if (drinksAlcohol == true) n++;
    return n;
  }

  double get _progress => (_stepIndex + 1) / _totalSteps;

  String _labelFor(String? key, List<(String, String)> options) {
    if (key == null) return '—';
    for (final o in options) {
      if (o.$1 == key) return o.$2;
    }
    return key;
  }

  Future<void> _save() async {
    if (socialMediaLevel == null || smokes == null || drinksAlcohol == null) return;
    setState(() => saving = true);
    final userId = context.read<AuthProvider>().user!.id;
    await Db.instance.raw.insert('bad_habit_checks', {
      'id': _uuid.v4(),
      'user_id': userId,
      'smokes': smokes! ? 1 : 0,
      'smoking_level': smokes! ? smokingLevel : null,
      'drinks_alcohol': drinksAlcohol! ? 1 : 0,
      'alcohol_level': drinksAlcohol! ? alcoholLevel : null,
      'social_media_level': socialMediaLevel,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await HealthIndexService.recalculate(userId);
    if (mounted) {
      setState(() {
        saving = false;
        step = _BadHabitsStep.done;
      });
    }
  }

  void _selectSmoking(bool value) {
    setState(() {
      smokes = value;
      step = value ? _BadHabitsStep.smokingLevel : _BadHabitsStep.alcohol;
      if (!value) smokingLevel = null;
    });
  }

  void _selectSmokingLevel(String value) {
    setState(() {
      smokingLevel = value;
      step = _BadHabitsStep.alcohol;
    });
  }

  void _selectAlcohol(bool value) {
    setState(() {
      drinksAlcohol = value;
      step = value ? _BadHabitsStep.alcoholLevel : _BadHabitsStep.socialMedia;
      if (!value) alcoholLevel = null;
    });
  }

  void _selectAlcoholLevel(String value) {
    setState(() {
      alcoholLevel = value;
      step = _BadHabitsStep.socialMedia;
    });
  }

  void _selectSocialMedia(String value) {
    setState(() => socialMediaLevel = value);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (step == _BadHabitsStep.done) {
      return AppModal(
        title: 'Bad Habits Summary',
        onClose: () => Navigator.pop(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow(
              'Smoking',
              smokes!
                  ? _labelFor(smokingLevel, _smokingLevels)
                  : 'No',
            ),
            const SizedBox(height: 12),
            _summaryRow(
              'Alcohol',
              drinksAlcohol!
                  ? _labelFor(alcoholLevel, _alcoholLevels)
                  : 'No',
            ),
            const SizedBox(height: 12),
            _summaryRow(
              'Social media',
              _labelFor(socialMediaLevel, _socialMediaLevels),
            ),
            const SizedBox(height: 20),
            Text(
              'Saved to your health history. Honest tracking is the first step toward change.',
              style: TextStyle(fontSize: 13, color: C.gray500, height: 1.4),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }

    return AppModal(
      title: 'Check Your Bad Habits',
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${_stepIndex + 1} of $_totalSteps',
                  style: TextStyle(fontSize: 12, color: C.gray500)),
              Text('${(_progress * 100).round()}% complete',
                  style: TextStyle(fontSize: 12, color: C.gray500)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: C.gray100,
              valueColor: AlwaysStoppedAnimation(C.blue500),
            ),
          ),
          const SizedBox(height: 24),
          if (step == _BadHabitsStep.smoking) ...[
            Text('Do you smoke?',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            _yesNoRow(onYes: () => _selectSmoking(true), onNo: () => _selectSmoking(false)),
          ] else if (step == _BadHabitsStep.smokingLevel) ...[
            Text('How much do you smoke?',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            ..._smokingLevels.map((o) => _optionTile(o.$2, () => _selectSmokingLevel(o.$1))),
          ] else if (step == _BadHabitsStep.alcohol) ...[
            Text('Do you drink alcohol?',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            _yesNoRow(
                onYes: () => _selectAlcohol(true), onNo: () => _selectAlcohol(false)),
          ] else if (step == _BadHabitsStep.alcoholLevel) ...[
            Text('How often and how much do you drink?',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            ..._alcoholLevels.map((o) => _optionTile(o.$2, () => _selectAlcoholLevel(o.$1))),
          ] else if (step == _BadHabitsStep.socialMedia) ...[
            Text('How much time do you spend uselessly on social media?',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            if (saving)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._socialMediaLevels
                  .map((o) => _optionTile(o.$2, () => _selectSocialMedia(o.$1))),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.gray100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: C.gray500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, color: C.gray800, height: 1.35)),
        ],
      ),
    );
  }

  Widget _yesNoRow({required VoidCallback onYes, required VoidCallback onNo}) {
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(label: 'Yes', color: C.blue600, onPressed: onYes),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: onNo,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: C.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('No', style: TextStyle(fontWeight: FontWeight.w600, color: C.gray700)),
          ),
        ),
      ],
    );
  }

  Widget _optionTile(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.gray200),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray800)),
        ),
      ),
    );
  }
}

enum _BadHabitsStep { smoking, smokingLevel, alcohol, alcoholLevel, socialMedia, done }

// ── Start physical activity ──────────────────────────────────────────────────
class _ActivityProgram {
  final String id;
  final String label;
  final String subtitle;
  final List<String> exercises;
  final String? note;

  const _ActivityProgram({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.exercises,
    this.note,
  });
}

class PhysicalActivityModal extends StatefulWidget {
  const PhysicalActivityModal({super.key});

  @override
  State<PhysicalActivityModal> createState() => _PhysicalActivityModalState();
}

class _PhysicalActivityModalState extends State<PhysicalActivityModal> {
  static const _programs = [
    _ActivityProgram(
      id: 'starter',
      label: 'Starter',
      subtitle: 'Begin your daily physical activity',
      exercises: [
        'I will do 15 push-ups throughout the day',
        '20 squats per day',
        '20 sit-ups',
        '15 push-ups from a couch or other object behind your back',
      ],
    ),
    _ActivityProgram(
      id: 'advanced',
      label: 'Advanced',
      subtitle: 'Build consistency with structured sets',
      exercises: [
        '45 push-ups throughout the day. Recommended: 20, 15, 10',
        '50 squats per day, 2 sets of 25',
        '30 sit-ups, 20 front raises, and 10 leg raises with knees bent',
        '25 push-ups from a couch or other object behind your back, 15, and 10',
      ],
      note: 'Rest no more than 2 minutes between sets.',
    ),
    _ActivityProgram(
      id: 'professional',
      label: 'Professional',
      subtitle: 'High-volume daily bodyweight training',
      exercises: [
        'Over 100 push-ups per day',
        'Over 100 squats throughout the day',
        'Over 70 abdominal exercises per day',
        'Over 60 push-ups behind the back throughout the day',
      ],
      note: 'Rest no more than 2 minutes between sets.',
    ),
    _ActivityProgram(
      id: 'superman',
      label: 'Superman',
      subtitle: 'Gym-based vigorous training',
      exercises: [
        'I work out in the gym 3 or more times a week for more than 60 minutes vigorously',
      ],
    ),
  ];

  _ActivityProgram? selected;
  _ActivityProgram? active;
  bool loading = true;
  bool changingPlan = false;
  bool saving = false;
  bool saved = false;

  @override
  void initState() {
    super.initState();
    _loadActive();
  }

  _ActivityProgram? _byId(String? id) {
    if (id == null) return null;
    for (final p in _programs) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _loadActive() async {
    final userId = context.read<AuthProvider>().user!.id;
    final row = await PhysicalActivityService.activeProgram(userId);
    if (!mounted) return;
    setState(() {
      active = _byId(row?['program_id'] as String?);
      // Fallback if DB has a label we don't recognize by id.
      if (active == null && row != null) {
        final label = row['program_label'] as String? ?? 'Your plan';
        active = _ActivityProgram(
          id: row['program_id'] as String? ?? 'custom',
          label: label,
          subtitle: 'Your current physical activity plan',
          exercises: const [
            'Your plan is active. Complete your daily workout and answer the evening check-in.',
          ],
        );
      }
      loading = false;
    });
  }

  Future<void> _save(_ActivityProgram program) async {
    setState(() {
      selected = program;
      saving = true;
    });
    final userId = context.read<AuthProvider>().user!.id;
    await Db.instance.raw.insert('physical_activity_programs', {
      'id': _uuid.v4(),
      'user_id': userId,
      'program_id': program.id,
      'program_label': program.label,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await PhysicalActivityService.scheduleEveningReminder(userId);
    if (mounted) {
      setState(() {
        saving = false;
        saved = true;
        active = program;
        changingPlan = false;
      });
    }
  }

  Widget _exerciseList(_ActivityProgram p, {bool checkmarks = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...p.exercises.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: checkmarks
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle, size: 18, color: C.teal600),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e,
                          style: TextStyle(fontSize: 14, color: C.gray800, height: 1.35),
                        ),
                      ),
                    ],
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: C.gray100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.gray200),
                    ),
                    child: Text(
                      e,
                      style: TextStyle(fontSize: 14, color: C.gray800, height: 1.35),
                    ),
                  ),
          ),
        ),
        if (p.note != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.amber50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.amber200),
            ),
            child: Text(
              p.note!,
              style: TextStyle(fontSize: 13, color: C.amber700, height: 1.35),
            ),
          ),
        ],
      ],
    );
  }

  Widget _activePlanView(_ActivityProgram p) {
    return AppModal(
      title: 'Your activity plan',
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.teal50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.teal200),
            ),
            child: Row(
              children: [
                Icon(Icons.fitness_center, color: C.teal600, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current plan',
                        style: TextStyle(fontSize: 12, color: C.teal700),
                      ),
                      Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: C.gray900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p.subtitle,
            style: TextStyle(fontSize: 13, color: C.gray500, height: 1.35),
          ),
          const SizedBox(height: 16),
          Text(
            "What's included",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.gray800,
            ),
          ),
          const SizedBox(height: 10),
          _exerciseList(p, checkmarks: true),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Change plan',
            color: C.blue600,
            onPressed: () => setState(() {
              changingPlan = true;
              selected = null;
              saved = false;
            }),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: C.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.w600, color: C.gray700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return AppModal(
        title: 'Physical activity',
        onClose: () => Navigator.pop(context),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Already on a plan — show details unless user asked to change.
    if (active != null && !changingPlan && !saved) {
      return _activePlanView(active!);
    }

    if (saved && selected != null) {
      final p = selected!;
      return AppModal(
        title: 'Program started',
        onClose: () => Navigator.pop(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              p.label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: C.gray900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your daily physical activity plan is saved. Every evening we will ask if you completed it.',
              style: TextStyle(fontSize: 13, color: C.gray500, height: 1.4),
            ),
            const SizedBox(height: 16),
            _exerciseList(p, checkmarks: true),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }

    if (selected != null && !saved) {
      final p = selected!;
      return AppModal(
        title: p.label,
        onClose: () => Navigator.pop(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              changingPlan
                  ? 'Switch to this program:'
                  : 'Start your daily physical activity with this program:',
              style: TextStyle(fontSize: 14, color: C.gray600, height: 1.4),
            ),
            const SizedBox(height: 16),
            _exerciseList(p),
            const SizedBox(height: 20),
            if (saving)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              PrimaryButton(
                label: changingPlan ? 'Switch to this plan' : 'Start this program',
                color: C.teal600,
                onPressed: () => _save(p),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => setState(() => selected = null),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: C.cardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Choose another',
                  style: TextStyle(fontWeight: FontWeight.w600, color: C.gray700),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return AppModal(
      title: changingPlan ? 'Change plan' : 'Start physical activity',
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            changingPlan
                ? 'Pick a new program. Your evening check-in will follow the new plan.'
                : 'Choose your program. Start your daily physical activity.',
            style: TextStyle(fontSize: 14, color: C.gray600, height: 1.4),
          ),
          const SizedBox(height: 16),
          ..._programs.map((p) {
            final isCurrent = active?.id == p.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => selected = p),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? C.teal400 : C.gray200,
                      width: isCurrent ? 1.5 : 1,
                    ),
                    color: isCurrent ? C.teal50 : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p.label,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: C.gray900,
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: C.teal100,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      'Current',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: C.teal700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.subtitle,
                              style: TextStyle(fontSize: 13, color: C.gray500),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: C.gray400),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (changingPlan && active != null) ...[
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: () => setState(() => changingPlan = false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: C.cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Keep current plan',
                style: TextStyle(fontWeight: FontWeight.w600, color: C.gray700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Daily BP / glucose (once per calendar day) ───────────────────────────────
class DailyVitalsDialog extends StatefulWidget {
  final bool needBp;
  final bool needGlucose;
  final String unitSystem;

  const DailyVitalsDialog({
    super.key,
    required this.needBp,
    required this.needGlucose,
    required this.unitSystem,
  });

  @override
  State<DailyVitalsDialog> createState() => _DailyVitalsDialogState();
}

class _DailyVitalsDialogState extends State<DailyVitalsDialog> {
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _glucose = TextEditingController();
  bool saving = false;
  String error = '';

  bool get isImperial => widget.unitSystem == 'imperial';

  @override
  void dispose() {
    _systolic.dispose();
    _diastolic.dispose();
    _glucose.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => error = '');
    final userId = context.read<AuthProvider>().user!.id;
    final now = DateTime.now().toUtc().toIso8601String();
    final inserts = <Map<String, dynamic>>[];

    if (widget.needBp) {
      if (_systolic.text.trim().isEmpty && _diastolic.text.trim().isEmpty) {
        // BP optional if glucose still needed
      } else {
        if (_systolic.text.trim().isEmpty || _diastolic.text.trim().isEmpty) {
          setState(() => error = 'Enter both blood pressure values, or leave both empty.');
          return;
        }
        final sys = double.tryParse(_systolic.text.trim());
        final dia = double.tryParse(_diastolic.text.trim());
        final bpErr = VitalValidation.bloodPressure(sys, dia);
        if (bpErr != null) {
          setState(() => error = bpErr);
          return;
        }
        inserts.addAll([
          {
            'id': _uuid.v4(),
            'user_id': userId,
            'metric_type': 'blood_pressure_systolic',
            'value': sys,
            'recorded_at': now,
            'created_at': now,
          },
          {
            'id': _uuid.v4(),
            'user_id': userId,
            'metric_type': 'blood_pressure_diastolic',
            'value': dia,
            'recorded_at': now,
            'created_at': now,
          },
        ]);
      }
    }

    if (widget.needGlucose && _glucose.text.trim().isNotEmpty) {
      final g = double.tryParse(_glucose.text.trim());
      double? glucoseMgdl;
      final gErr = VitalValidation.glucoseUserInput(
        g,
        isImperial ? 'imperial' : 'metric',
        onValid: (mgdl) => glucoseMgdl = mgdl,
      );
      if (gErr != null) {
        setState(() => error = gErr);
        return;
      }
      inserts.add({
        'id': _uuid.v4(),
        'user_id': userId,
        'metric_type': 'glucose',
        'value': glucoseMgdl,
        'recorded_at': now,
        'created_at': now,
      });
    }

    if (inserts.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => saving = true);
    for (final row in inserts) {
      await Db.instance.raw.insert('health_metrics', row);
    }
    if (inserts.any((r) => r['metric_type'] == 'blood_pressure_systolic')) {
      await DailyVitalsService.markBpLogged(userId);
    }
    if (inserts.any((r) => r['metric_type'] == 'glucose')) {
      await DailyVitalsService.markGlucoseLogged(userId);
    }
    // Ensure today's prompt won't reopen even if Dashboard remounts.
    if (widget.needBp) await DailyVitalsService.markBpPromptDismissed(userId);
    if (widget.needGlucose) {
      await DailyVitalsService.markGlucosePromptDismissed(userId);
    }
    await DailyVitalsService.recordPromptHandled(userId);
    await HealthIndexService.recalculate(userId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Today\'s vitals', style: TextStyle(color: C.gray900, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Log blood pressure and glucose once per day. You can skip and log later.',
              style: TextStyle(fontSize: 13, color: C.gray500, height: 1.4),
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final userId =
                                    context.read<AuthProvider>().user!.id;
                                await DailyVitalsService.setPromptMode(
                                  userId,
                                  VitalsPromptMode.off,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context, false);
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'Turn Off',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: C.gray800,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Skip daily BP/glucose prompts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: C.gray500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final userId =
                                    context.read<AuthProvider>().user!.id;
                                await DailyVitalsService.setPromptMode(
                                  userId,
                                  VitalsPromptMode.every5Days,
                                );
                                if (widget.needBp) {
                                  await DailyVitalsService
                                      .markBpPromptDismissed(userId);
                                }
                                if (widget.needGlucose) {
                                  await DailyVitalsService
                                      .markGlucosePromptDismissed(userId);
                                }
                                if (context.mounted) {
                                  Navigator.pop(context, false);
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'Ask once in 5 days',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: C.gray800,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Remind every 5 days, not daily.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: C.gray500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (error.isNotEmpty) ...[
              SizedBox(height: 12),
              AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700),
            ],
            if (widget.needBp) ...[
              SizedBox(height: 16),
              Text('Blood pressure (mmHg)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: C.gray900)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _systolic,
                      keyboardType: TextInputType.number,
                      decoration: appInput('Systolic'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _diastolic,
                      keyboardType: TextInputType.number,
                      decoration: appInput('Diastolic'),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.needGlucose) ...[
              SizedBox(height: 16),
              Text(
                'Blood glucose (${isImperial ? 'mg/dL' : 'mmol/L'})',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _glucose,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: appInput(isImperial ? 'e.g. 95' : 'e.g. 5.3'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () async {
                  final userId = context.read<AuthProvider>().user!.id;
                  if (widget.needBp) await DailyVitalsService.markBpPromptDismissed(userId);
                  if (widget.needGlucose) {
                    await DailyVitalsService.markGlucosePromptDismissed(userId);
                  }
                  if (context.mounted) Navigator.pop(context, false);
                },
          child: Text('Not now'),
        ),
        TextButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Saving…' : 'Save'),
        ),
      ],
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
    final storage = toStorageValue(metricType, num, auth.unitSystem);
    final rangeErr = VitalValidation.metricStorage(metricType, storage);
    if (rangeErr != null) {
      setState(() => error = rangeErr);
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    final now = DateTime.now().toUtc().toIso8601String();
    final userId = auth.user!.id;
    if (DailyMetricStore.isDailyLiveMetric(metricType)) {
      await DailyMetricStore.upsertToday(
        userId: userId,
        metricType: metricType,
        value: storage,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        source: 'manual',
      );
    } else {
      await Db.instance.raw.insert('health_metrics', {
        'id': _uuid.v4(),
        'user_id': userId,
        'metric_type': metricType,
        'value': storage,
        'recorded_at': now,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'created_at': now,
      });
    }
    if (metricType == 'glucose') {
      await DailyVitalsService.markGlucoseLogged(userId);
    }
    await HealthIndexService.recalculate(userId);
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
            SizedBox(height: 16),
          ],
          if (success) ...[
            AppBanner(text: 'Metric saved!', bg: C.green50, border: C.green200, fg: C.teal700),
            SizedBox(height: 16),
          ],
          Text('Metric Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
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
          SizedBox(height: 16),
          Text('Value  (${selected.unit})',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
          TextField(controller: _value, decoration: appInput(selected.hint)),
          SizedBox(height: 16),
          Text('Notes  (optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
          TextField(controller: _notes, decoration: appInput('Any additional notes...')),
          SizedBox(height: 16),
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
  final bool trialExpired;
  const UpgradeModal({super.key, this.trialExpired = false});

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
    final auth = context.watch<AuthProvider>();
    final isPlus = auth.isPlus;
    final hpDiscount = auth.hpDiscountEligible;
    final trialExpired = widget.trialExpired || auth.isTrialExpired;
    if (isPlus || done) {
      return AppModal(
        title: '',
        onClose: () => Navigator.pop(context),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: C.amber50, shape: BoxShape.circle),
              child: Icon(Icons.check_circle, color: C.amber500, size: 32),
            ),
            SizedBox(height: 16),
            Text("You're on PHA Plus+!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: C.gray900)),
            SizedBox(height: 8),
            Text(
                'All features are now unlocked. Enjoy unlimited uploads, PsychoTest, and Treatment Schedule.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: C.gray500)),
          ],
        ),
      );
    }

    const features = [
      ('Analysis Uploads', '2 files', 'Unlimited'),
      ('Meal Calorie Checks', '2 / 24h', 'Unlimited'),
      ('Pages per File', '2 pages', 'Unlimited'),
      ('PsychoTest', 'Locked', 'Full access'),
      ('Treatment Schedule', 'Locked', 'Full access'),
      ('Check Your Bad Habits', 'Locked', 'Full access'),
      ('Start physical activity', 'Locked', 'Full access'),
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
              children: [
                Icon(Icons.auto_awesome, size: 16, color: C.white),
                SizedBox(width: 8),
                Text('PHA Plus+',
                    style: TextStyle(color: C.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          SizedBox(height: 16),
          if (trialExpired) ...[
            Text('Unlock All Features of PHA Plus+',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
            SizedBox(height: 12),
            Text(
              'Take full control of your health! Unlock all premium options in PHA Plus+ '
              'and gain the ability to monitor your health, physical activity, nutrition, '
              'and medical indicators in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: C.gray600),
            ),
            SizedBox(height: 10),
            Text(
              'Stay informed about potential risks and easily adjust your lifestyle. '
              'Count calories without any limits, correlate them with your daily activity levels, '
              'and receive personalized recommendations based on your medical data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: C.gray600),
            ),
            SizedBox(height: 10),
            Text(
              'Your health. Your control. Always.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: C.gray800,
              ),
            ),
          ] else ...[
            Text('Unlock All Features',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
            SizedBox(height: 8),
            Text('Get the full power of your Personal Health Assistant',
                style: TextStyle(fontSize: 14, color: C.gray500)),
          ],
          if (hpDiscount) ...[
            SizedBox(height: 12),
            AppBanner(
              text:
                  'You have $maxOnboardingHp HP! Redeem for $hpFirstPurchaseDiscountPercent% off 6-month or annual plans.',
              bg: C.amber50,
              border: C.amber200,
              fg: C.amber700,
            ),
          ],
          SizedBox(height: 24),
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
                    children: [
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
                      decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: C.gray100))),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text(f.$1,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: C.gray700))),
                          Expanded(
                              child: Text(f.$2,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: C.gray400))),
                          Expanded(
                              child: Text(f.$3,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: C.emerald600))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          SizedBox(height: 24),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _planCard(
                    plan: 'monthly',
                    name: 'Monthly',
                    price: planListPrice('monthly'),
                    per: '/mo',
                    note: 'Billed monthly.',
                    best: false,
                    discounted: false,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _planCard(
                    plan: 'semiannual',
                    name: '6 Months',
                    price: hpDiscount ? planDiscountedPrice('semiannual') : planListPrice('semiannual'),
                    per: '/6mo',
                    note: hpDiscount ? '20% HP discount applied.' : 'Save ~17%.',
                    best: false,
                    discounted: hpDiscount,
                    listPrice: planListPrice('semiannual'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _planCard(
                    plan: 'annual',
                    name: 'Annual',
                    price: hpDiscount ? planDiscountedPrice('annual') : planListPrice('annual'),
                    per: '/yr',
                    note: hpDiscount ? '20% HP discount applied.' : 'Save ~42%.',
                    best: true,
                    discounted: hpDiscount,
                    listPrice: planListPrice('annual'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.teal50, C.blue50]),
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
                  child: Icon(Icons.psychology, color: C.teal600, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

  static TextStyle get _thStyle =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.gray500);

  Widget _planCard({
    required String plan,
    required String name,
    required String price,
    required String per,
    required String note,
    required bool best,
    required bool discounted,
    String? listPrice,
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
                    child: Text('BEST',
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
          SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (discounted && listPrice != null) ...[
                  Text(listPrice,
                      style: TextStyle(
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          color: C.gray400)),
                  SizedBox(width: 4),
                ],
                Text(price,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: C.gray900)),
                Text(per, style: TextStyle(fontSize: 10, color: C.gray400)),
              ],
            ),
          ),
          SizedBox(height: 4),
          Text(note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: C.gray400, height: 1.2)),
          Spacer(),
          SizedBox(height: 8),
          GestureDetector(
            onTap: loadingPlan != null ? null : () => _upgrade(plan),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration:
                  BoxDecoration(gradient: kAmberGradient, borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: loadingPlan == plan
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: C.white),
                      )
                    : Icon(Icons.auto_awesome, size: 14, color: C.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
