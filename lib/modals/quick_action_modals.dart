import 'dart:async';
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
import '../l10n/l10n_ext.dart';
import '../l10n/medical_l10n.dart';

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
    late final FilePickerResult? result;
    switch (fileType) {
      case 'pdf':
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
      case 'dicom':
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['dcm', 'dicom'],
        );
      default:
        result = await FilePicker.pickFiles(type: FileType.image);
    }
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        fileName = result!.files.first.name;
        filePath = result.files.first.path;
        fileSize = result.files.first.size;
      });
    }
  }

  String? _filePickerHint(AppLocalizations l10n, AuthProvider auth) {
    if (atLimit) return l10n.uploadUpgradeMore;
    return switch (fileType) {
      'pdf' => auth.isPlus ? null : l10n.fileTypePdf,
      'dicom' => l10n.fileTypeDicom,
      _ => l10n.uploadImageFormats,
    };
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
      setState(() => error = context.l10n.uploadCouldNotRead);
      return;
    }
    setState(() {
      uploading = true;
      error = '';
    });
    final uploadedName = fileName!;
    final l10nUpload = context.l10n;
    try {
      final textLogs =
          await AiConsultationService.buildAnalysisUploadPrompt(auth.user!.id);
      final uploadPath = fileType == 'photo'
          ? await compressImageForUpload(
              filePath!,
              quality: 60,
              maxWidth: 800,
              maxHeight: 800,
            )
          : filePath!;
      final analysis = fileType == 'dicom'
          ? await AiConsultationService.analyzeDicomUpload(
              userId: auth.user!.id,
              filePath: uploadPath,
            )
          : await ApiClient.analyze(
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
        userMessage: l10nUpload.aiDocUploadedAnalysis(uploadedName),
      );
      // Don't block opening Ai Doc chat on network sync.
      unawaited(auth.syncPatientHistory());
      if (!auth.isPlus && uploadCount != null) {
        uploadCount = uploadCount! + 1;
      }
      if (!mounted) return;
      widget.onAnalysisDelivered(analysis, uploadedName);
    } on ApiException catch (e) {
      setState(() => error = e.userFacingMessage);
    } catch (e) {
      setState(() => error = context.l10n.uploadFailed);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = context.l10n;
    return AppModal(
      title: l10n.uploadAnalysisTitle,
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!auth.isPlus && uploadCount != null) ...[
            AppBanner(
              text: atLimit
                  ? l10n.uploadLimitMessage
                  : l10n.uploadFreePlan(uploadCount!),
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
              text: fileType == 'dicom'
                  ? l10n.uploadAnalyzingDicom
                  : l10n.uploadAnalyzingAiDoc,
              bg: C.blue50,
              border: C.blue100,
              fg: C.blue700,
            ),
            SizedBox(height: 16),
          ],
          Text(l10n.uploadFileType,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: fileType,
            decoration: appInput(''),
            items: [
              DropdownMenuItem(value: 'pdf', child: Text(l10n.uploadPdf)),
              DropdownMenuItem(value: 'photo', child: Text(l10n.uploadPhoto)),
              DropdownMenuItem(value: 'dicom', child: Text(l10n.uploadDicom)),
            ],
            onChanged: atLimit
                ? null
                : (v) => setState(() {
                      fileType = v!;
                      fileName = null;
                      filePath = null;
                      fileSize = null;
                    }),
          ),
          SizedBox(height: 16),
          Text(l10n.uploadSelectFile,
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
                    Text(l10n.uploadClickToChange(((fileSize ?? 0) / 1024).round()),
                        style: TextStyle(fontSize: 12, color: C.gray400)),
                  ] else ...[
                    Text(atLimit ? l10n.uploadLimitReached : l10n.uploadClickToSelect,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: atLimit ? C.gray400 : C.gray600)),
                    if (_filePickerHint(l10n, auth) case final hint?) ...[
                      Text(
                        hint,
                        style: TextStyle(fontSize: 12, color: C.gray400),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          atLimit
              ? PrimaryButton(
                  label: l10n.upgradeToPhaPlus,
                  color: C.amber500,
                  icon: Icon(Icons.auto_awesome, size: 16, color: C.white),
                  onPressed: widget.onNeedUpgrade,
                )
              : PrimaryButton(
                  label: uploading ? l10n.uploadAnalyzing : l10n.uploadFile,
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
      setState(() => error = context.l10n.mealFailed);
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
    final l10n = context.l10n;
    final atLimit = _isAtLimit(auth);
    final pending = pendingResult;

    return AppModal(
      title: l10n.actionMealCalories,
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!auth.isPlus && checksLast24h != null) ...[
            AppBanner(
              text: atLimit
                  ? l10n.mealFreeLimit
                  : l10n.mealFreePlan(checksLast24h!, MealCalorieService.freeDailyLimit),
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
              text: l10n.mealLogged,
              bg: C.green50,
              border: C.green200,
              fg: C.teal700,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 16),
          ],
          if (analyzing) ...[
            AppBanner(
              text: l10n.mealAnalyzing,
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
              l10n.mealTakePhoto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: C.gray700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.mealAfterAnalysis,
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
                    label: Text(l10n.mealCamera, style: TextStyle(color: C.gray700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        analyzing || atLimit ? null : () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library_outlined, color: C.gray600),
                    label: Text(l10n.mealGallery, style: TextStyle(color: C.gray700)),
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
                    label: l10n.upgradeToPhaPlus,
                    color: C.amber500,
                    icon: Icon(Icons.auto_awesome, size: 16, color: C.white),
                    onPressed: widget.onNeedUpgrade,
                  )
                : PrimaryButton(
                    label: analyzing ? l10n.mealAnalyzing : l10n.mealAnalyze,
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
    final l10n = context.l10n;
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
            l10n.mealTapConfirm,
            style: TextStyle(fontSize: 12, color: C.gray500, height: 1.35),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: confirming ? null : onDiscard,
            child: Text(
              l10n.mealDiscard,
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
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.mealTotalIntake,
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
          l10n.mealQualityTargetLine(summary.qualityLabel, summary.targetCalories),
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
                  label: l10n.mealCarb,
                  value: '${summary.carbsG.toStringAsFixed(0)}g',
                  color: C.amber500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroChip(
                  label: l10n.mealProteins,
                  value: '${summary.proteinG.toStringAsFixed(0)}g',
                  color: C.teal600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroChip(
                  label: l10n.mealFat,
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
              l10n.mealNoMealsToday,
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
  final _messages = <_Msg>[];
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
    final l10n = context.l10n;
    setState(() {
      for (final r in rows) {
        _messages.add(_Msg(true, r['message'] as String));
        _messages.add(_Msg(false, r['response'] as String));
      }
      final seeds = widget.seedMessages;
      if (seeds != null) {
        for (final m in seeds) {
          // Avoid duplicating the exchange already saved via recordAnalysisInChat.
          final exists = _messages.any(
            (x) => x.isUser == m.isUser && x.text == m.text,
          );
          if (!exists) _messages.add(_Msg(m.isUser, m.text));
        }
      } else if (rows.isEmpty && _messages.isEmpty) {
        _messages.add(_Msg(false, l10n.aiDocWelcome));
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
            context.l10n.aiDocNoProblem;
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
    final l10n = context.l10n;
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
          l10n.aiDocTitle,
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
                      l10n.aiDocOffline,
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
                      ? l10n.aiDocFreeLimit
                      : l10n.aiDocFreeRemaining(3 - consultCount!),
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
                                  ? l10n.aiDocAnalyzingHealth
                                  : l10n.aiDocLooking)
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
                    tooltip: l10n.mealCamera,
                    onPressed: (loading || atLimit)
                        ? null
                        : () => _pickPhoto(ImageSource.camera),
                    icon: Icon(Icons.photo_camera_outlined,
                        color: (loading || atLimit) ? C.gray300 : C.blue600),
                  ),
                  IconButton(
                    tooltip: l10n.mealGallery,
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
                              ? l10n.aiDocUpgradeChat
                              : l10n.aiDocAskPlaceholder)
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
    final l10n = context.l10n;
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
                    l10n.aiDocPhoto,
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
  List<(String, bool)> _questions(AppLocalizations l10n) => [
    (l10n.wellnessQ1, true),
    (l10n.wellnessQ2, false),
    (l10n.wellnessQ3, false),
    (l10n.wellnessQ4, false),
    (l10n.wellnessQ5, false),
  ];

  List<String> _labels(AppLocalizations l10n) => [
    l10n.wellnessVeryPoor,
    l10n.wellnessPoor,
    l10n.wellnessModerate,
    l10n.wellnessGood,
    l10n.wellnessExcellent,
  ];

  int current = 0;
  final answers = <int>[];
  bool showResult = false;
  bool saving = false;

  Future<void> _answer(int raw) async {
    final questions = _questions(context.l10n);
    if (current < 0 || current >= questions.length) return;
    final reverse = questions[current].$2;
    final score = reverse ? (6 - raw) * 20 : raw * 20;
    answers.add(score);
    if (current < questions.length - 1) {
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
    final l10n = context.l10n;
    final questions = _questions(l10n);
    final labels = _labels(l10n);
    if (showResult) {
      final avg = (answers.fold<int>(0, (a, b) => a + b) / answers.length).round();
      final med = WellnessGuidelines.classify(avg);
      final result = l10n.statusLabel(med.band == 'moderate' ? 'fair' : med.band);
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
      final descText = l10n.wellnessMessage(med.band);
      return AppModal(
        title: l10n.wellnessResults,
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
            PrimaryButton(label: context.l10n.done, onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }

    final progress = current / questions.length;
    return AppModal(
      title: l10n.actionWellnessCheck,
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.wellnessQuestion(current + 1, questions.length),
                  style: TextStyle(fontSize: 12, color: C.gray500)),
              Text(l10n.percentComplete((progress * 100).round()),
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
              (current >= 0 && current < questions.length)
                  ? questions[current].$1
                  : l10n.questionUnavailable,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
          SizedBox(height: 24),
          ...List.generate(5, (i) {
            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
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
                      Text(labels[i],
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
  List<(String, String)> _smokingLevels(AppLocalizations l10n) => [
    ('less_than_one_pack', l10n.badHabitsSmokeLessPack),
    ('one_pack', l10n.badHabitsSmokeOnePack),
    ('more_than_one_pack', l10n.badHabitsSmokeMorePack),
  ];

  List<(String, String)> _alcoholLevels(AppLocalizations l10n) => [
    ('occasionally', l10n.badHabitsAlcoholOccasionally),
    ('regularly', l10n.badHabitsAlcoholRegularly),
    ('heavy', l10n.badHabitsAlcoholHeavy),
  ];

  List<(String, String)> _socialMediaLevels(AppLocalizations l10n) => [
    ('rarely', l10n.badHabitsSocialRarely),
    ('under_hour', l10n.badHabitsSocialUnderHour),
    ('one_to_two_hours', l10n.badHabitsSocialOneTwoHours),
    ('constantly', l10n.badHabitsSocialConstantly),
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
    final l10n = context.l10n;
    if (step == _BadHabitsStep.done) {
      return AppModal(
        title: l10n.badHabitsSummaryTitle,
        onClose: () => Navigator.pop(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow(
              l10n.categorySmoking,
              smokes!
                  ? _labelFor(smokingLevel, _smokingLevels(l10n))
                  : l10n.no,
            ),
            const SizedBox(height: 12),
            _summaryRow(
              l10n.categoryAlcohol,
              drinksAlcohol!
                  ? _labelFor(alcoholLevel, _alcoholLevels(l10n))
                  : l10n.no,
            ),
            const SizedBox(height: 12),
            _summaryRow(
              l10n.badHabitsSocialMediaLabel,
              _labelFor(socialMediaLevel, _socialMediaLevels(l10n)),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.badHabitsSaved,
              style: TextStyle(fontSize: 13, color: C.gray500, height: 1.4),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: l10n.done, onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }

    return AppModal(
      title: l10n.actionBadHabits,
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.badHabitsStep(_stepIndex + 1, _totalSteps),
                  style: TextStyle(fontSize: 12, color: C.gray500)),
              Text(l10n.percentComplete((_progress * 100).round()),
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
            Text(l10n.badHabitsDoYouSmoke,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            _yesNoRow(onYes: () => _selectSmoking(true), onNo: () => _selectSmoking(false)),
          ] else if (step == _BadHabitsStep.smokingLevel) ...[
            Text(l10n.badHabitsHowMuchSmoke,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            ..._smokingLevels(l10n).map((o) => _optionTile(o.$2, () => _selectSmokingLevel(o.$1))),
          ] else if (step == _BadHabitsStep.alcohol) ...[
            Text(l10n.badHabitsDoYouDrink,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            _yesNoRow(
                onYes: () => _selectAlcohol(true), onNo: () => _selectAlcohol(false)),
          ] else if (step == _BadHabitsStep.alcoholLevel) ...[
            Text(l10n.badHabitsHowMuchDrink,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            ..._alcoholLevels(l10n).map((o) => _optionTile(o.$2, () => _selectAlcoholLevel(o.$1))),
          ] else if (step == _BadHabitsStep.socialMedia) ...[
            Text(l10n.badHabitsSocialMedia,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: C.gray900)),
            const SizedBox(height: 16),
            if (saving)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._socialMediaLevels(l10n)
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
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(label: l10n.yes, color: C.blue600, onPressed: onYes),
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
            child: Text(l10n.no, style: TextStyle(fontWeight: FontWeight.w600, color: C.gray700)),
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

  _ActivityProgram _localizedProgram(_ActivityProgram p, AppLocalizations l10n) {
    switch (p.id) {
      case 'starter':
        return _ActivityProgram(
          id: p.id,
          label: l10n.activityStarter,
          subtitle: l10n.activityStarterSubtitle,
          exercises: [
            l10n.activityStarterEx1,
            l10n.activityStarterEx2,
            l10n.activityStarterEx3,
            l10n.activityStarterEx4,
          ],
        );
      case 'advanced':
        return _ActivityProgram(
          id: p.id,
          label: l10n.activityAdvanced,
          subtitle: l10n.activityAdvancedSubtitle,
          exercises: [
            l10n.activityAdvancedEx1,
            l10n.activityAdvancedEx2,
            l10n.activityAdvancedEx3,
            l10n.activityAdvancedEx4,
          ],
          note: l10n.activityRestNote,
        );
      case 'professional':
        return _ActivityProgram(
          id: p.id,
          label: l10n.activityProfessional,
          subtitle: l10n.activityProfessionalSubtitle,
          exercises: [
            l10n.activityProEx1,
            l10n.activityProEx2,
            l10n.activityProEx3,
            l10n.activityProEx4,
          ],
          note: l10n.activityRestNote,
        );
      case 'superman':
        return _ActivityProgram(
          id: p.id,
          label: l10n.activitySuperman,
          subtitle: l10n.activitySupermanSubtitle,
          exercises: [l10n.activitySupermanEx1],
        );
      default:
        return _ActivityProgram(
          id: p.id,
          label: p.label,
          subtitle: l10n.activityCurrentPlanSubtitle,
          exercises: [l10n.activityCustomPlanHint],
        );
    }
  }

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
    final l10n = context.l10n;
    setState(() {
      active = _byId(row?['program_id'] as String?);
      // Fallback if DB has a label we don't recognize by id.
      if (active == null && row != null) {
        final label = row['program_label'] as String? ?? l10n.activityYourPlan;
        active = _ActivityProgram(
          id: row['program_id'] as String? ?? 'custom',
          label: label,
          subtitle: l10n.activityCurrentPlanSubtitle,
          exercises: [l10n.activityCustomPlanHint],
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
      title: context.l10n.activityYourPlan,
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
                        context.l10n.activityCurrentPlan,
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
            context.l10n.activityWhatsIncluded,
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
            label: context.l10n.activityChangePlan,
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
              context.l10n.close,
              style: TextStyle(fontWeight: FontWeight.w600, color: C.gray700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (loading) {
      return AppModal(
        title: l10n.activityStartTitle,
        onClose: () => Navigator.pop(context),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Already on a plan — show details unless user asked to change.
    if (active != null && !changingPlan && !saved) {
      return _activePlanView(_localizedProgram(active!, context.l10n));
    }

    if (saved && selected != null) {
      final p = selected!;
      return AppModal(
        title: context.l10n.activityProgramStarted,
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
              l10n.activityProgramSaved,
              style: TextStyle(fontSize: 13, color: C.gray500, height: 1.4),
            ),
            const SizedBox(height: 16),
            _exerciseList(p, checkmarks: true),
            const SizedBox(height: 20),
            PrimaryButton(label: l10n.done, onPressed: () => Navigator.pop(context)),
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
              changingPlan ? l10n.activitySwitchHint : l10n.activityStartHint,
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
                label: changingPlan ? context.l10n.activitySwitchToThis : context.l10n.activityStartThis,
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
                  context.l10n.activityChooseAnother,
                  style: TextStyle(fontWeight: FontWeight.w600, color: C.gray700),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return AppModal(
      title: changingPlan ? context.l10n.activityChangeTitle : context.l10n.activityStartTitle,
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            changingPlan
                ? context.l10n.activityChangeHint
                : context.l10n.activityChooseProgram,
            style: TextStyle(fontSize: 14, color: C.gray600, height: 1.4),
          ),
          const SizedBox(height: 16),
          ..._programs.map((raw) {
            final p = _localizedProgram(raw, context.l10n);
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
                                      context.l10n.activityCurrentBadge,
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
                context.l10n.activityKeepCurrent,
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
          setState(() => error = context.l10n.vitalsBpBothOrNone);
          return;
        }
        final sys = double.tryParse(_systolic.text.trim());
        final dia = double.tryParse(_diastolic.text.trim());
        final bpErr = VitalValidation.bloodPressure(sys, dia, context.l10n);
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
      final g = parseUserNumber(_glucose.text);
      double? glucoseMgdl;
      final gErr = VitalValidation.glucoseUserInput(
        g,
        isImperial ? 'imperial' : 'metric',
        context.l10n,
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
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.todayVitals, style: TextStyle(color: C.gray900, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.vitalsDailyPrompt,
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
                          l10n.vitalsPromptTurnOff,
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
                          l10n.vitalsPromptTurnOffHint,
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
                          l10n.vitalsPromptEvery5Days,
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
                          l10n.vitalsPromptEvery5DaysHint,
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
              Text(l10n.vitalsBpLabel,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: C.gray900)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _systolic,
                      keyboardType: TextInputType.number,
                      decoration: appInput(l10n.bpSystolic),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _diastolic,
                      keyboardType: TextInputType.number,
                      decoration: appInput(l10n.bpDiastolic),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.needGlucose) ...[
              SizedBox(height: 16),
              Text(
                l10n.vitalsGlucoseLabel(isImperial ? 'mg/dL' : 'mmol/L'),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _glucose,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: appInput(isImperial ? l10n.vitalsGlucoseHintImperial : l10n.vitalsGlucoseHintMetric),
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
          child: Text(l10n.notNow),
        ),
        TextButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? l10n.saving : l10n.save),
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

  List<({String value, String label, String unit, String hint})> _metrics(bool imp, AppLocalizations l10n) => [
        (value: 'steps', label: l10n.steps, unit: l10n.unitSteps, hint: l10n.logMetricHintSteps),
        (value: 'calories', label: l10n.calories, unit: l10n.unitKcal, hint: l10n.logMetricHintCalories),
        (value: 'distance', label: l10n.distance, unit: imp ? l10n.unitMiles : l10n.unitKm, hint: imp ? l10n.logMetricHintDistanceImperial : l10n.logMetricHintDistanceMetric),
        (value: 'active_time', label: l10n.activeTime, unit: l10n.unitMin, hint: l10n.logMetricHintActiveTime),
        (value: 'weight', label: l10n.weight, unit: imp ? l10n.unitLbs : l10n.unitKg, hint: imp ? l10n.logMetricHintWeightImperial : l10n.logMetricHintWeightMetric),
        (value: 'glucose', label: l10n.bloodGlucose, unit: imp ? 'mg/dL' : 'mmol/L', hint: imp ? l10n.vitalsGlucoseHintImperial : l10n.vitalsGlucoseHintMetric),
        (value: 'water', label: l10n.water, unit: l10n.unitMl, hint: l10n.logMetricHintWater),
      ];

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final num = parseUserNumber(_value.text);
    if (num == null || num < 0) {
      setState(() => error = context.l10n.enterValidPositiveNumber);
      return;
    }
    final storage = toStorageValue(metricType, num, auth.unitSystem);
    final l10n = context.l10n;
    final rangeErr = VitalValidation.metricStorage(metricType, storage, l10n);
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
    final l10n = context.l10n;
    final imp = context.watch<AuthProvider>().unitSystem == 'imperial';
    final metrics = _metrics(imp, l10n);
    final selected = metrics.firstWhere((m) => m.value == metricType);
    return AppModal(
      title: l10n.logHealthMetric,
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error.isNotEmpty) ...[
            AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700, icon: Icons.error_outline),
            SizedBox(height: 16),
          ],
          if (success) ...[
            AppBanner(text: l10n.metricSaved, bg: C.green50, border: C.green200, fg: C.teal700),
            SizedBox(height: 16),
          ],
          Text(l10n.metricType,
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
          Text(l10n.metricValueLabel(selected.unit),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
          TextField(controller: _value, decoration: appInput(selected.hint)),
          SizedBox(height: 16),
          Text(l10n.metricNotesOptional,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
          TextField(controller: _notes, decoration: appInput(l10n.metricNotesPlaceholder)),
          SizedBox(height: 16),
          PrimaryButton(
            label: saving ? l10n.saving : l10n.saveMetric,
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

  List<(String, String, String)> _upgradeFeatures(AppLocalizations l10n) => [
    (l10n.upgradeFeatAnalysisUploads, l10n.upgradeVal2Files, l10n.upgradeValUnlimited),
    (l10n.upgradeFeatMealCalories, l10n.upgradeVal2PerDay, l10n.upgradeValUnlimited),
    (l10n.upgradeFeatPagesPerFile, l10n.upgradeVal2Pages, l10n.upgradeValUnlimited),
    (l10n.upgradeFeatPsychoTest, l10n.upgradeValLocked, l10n.upgradeValFullAccess),
    (l10n.upgradeFeatTreatment, l10n.upgradeValLocked, l10n.upgradeValFullAccess),
    (l10n.upgradeFeatBadHabits, l10n.upgradeValLocked, l10n.upgradeValFullAccess),
    (l10n.upgradeFeatActivity, l10n.upgradeValLocked, l10n.upgradeValFullAccess),
    (l10n.upgradeFeatAiConsult, l10n.upgradeValIncluded, l10n.upgradeValIncluded),
    (l10n.upgradeFeatWellness, l10n.upgradeValIncluded, l10n.upgradeValIncluded),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
            Text(context.l10n.phaPlusUnlockedTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: C.gray900)),
            SizedBox(height: 8),
            Text(
                context.l10n.phaPlusUnlockedBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: C.gray500)),
          ],
        ),
      );
    }

    final features = _upgradeFeatures(l10n);

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
                Text(l10n.phaPlus,
                    style: TextStyle(color: C.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          SizedBox(height: 16),
          if (trialExpired) ...[
            Text(l10n.upgradeTrialTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
            SizedBox(height: 12),
            Text(l10n.upgradeTrialBody1,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: C.gray600),
            ),
            SizedBox(height: 10),
            Text(l10n.upgradeTrialBody2,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: C.gray600),
            ),
            SizedBox(height: 10),
            Text(l10n.upgradeTagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: C.gray800,
              ),
            ),
          ] else ...[
            Text(l10n.upgradeTitle,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
            SizedBox(height: 8),
            Text(l10n.upgradeSubtitle,
                style: TextStyle(fontSize: 14, color: C.gray500)),
          ],
          if (hpDiscount) ...[
            SizedBox(height: 12),
            AppBanner(
              text: l10n.upgradeHpBanner(maxOnboardingHp, hpFirstPurchaseDiscountPercent),
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
                      Expanded(flex: 2, child: Text(l10n.upgradeTableFeature, style: _thStyle)),
                      Expanded(child: Text(l10n.upgradeTableFree, textAlign: TextAlign.center, style: _thStyle)),
                      Expanded(
                          child: Text(l10n.upgradeTablePlus,
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
                    name: l10n.planMonthly,
                    price: planListPrice('monthly'),
                    per: l10n.planPerMonth,
                    note: l10n.planBilledMonthly,
                    best: false,
                    discounted: false,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _planCard(
                    plan: 'semiannual',
                    name: l10n.planSemiannual,
                    price: hpDiscount ? planDiscountedPrice('semiannual') : planListPrice('semiannual'),
                    per: l10n.planPer6Mo,
                    note: hpDiscount ? l10n.planHpDiscountNote : l10n.planSave17,
                    best: false,
                    discounted: hpDiscount,
                    listPrice: planListPrice('semiannual'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _planCard(
                    plan: 'annual',
                    name: l10n.planAnnual,
                    price: hpDiscount ? planDiscountedPrice('annual') : planListPrice('annual'),
                    per: l10n.planPerYear,
                    note: hpDiscount ? l10n.planHpDiscountNote : l10n.planSave42,
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
                      Text('${l10n.actionPsychoTest} — ${l10n.psychoTestSubtitle}',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: C.gray900)),
                      SizedBox(height: 2),
                      Text(l10n.psychoTestPromoBody,
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
                    child: Text(context.l10n.planBestBadge,
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
