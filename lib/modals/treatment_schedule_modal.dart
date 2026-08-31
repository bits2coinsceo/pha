import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../theme.dart';
import '../treatment_notifications.dart';
import '../treatment_schedule.dart';
import '../l10n/l10n_ext.dart';
import '../widgets.dart';

class _DraftEntry {
  final TextEditingController name = TextEditingController();
  int dosesPerDay = 1;
  List<TimeOfDay> doseTimes = [const TimeOfDay(hour: 8, minute: 0)];

  void dispose() => name.dispose();

  void setDosesPerDay(int value) {
    dosesPerDay = value;
    while (doseTimes.length < value) {
      final last = doseTimes.isNotEmpty ? doseTimes.last : const TimeOfDay(hour: 8, minute: 0);
      doseTimes.add(TimeOfDay(hour: (last.hour + 4) % 24, minute: last.minute));
    }
    if (doseTimes.length > value) {
      doseTimes = doseTimes.sublist(0, value);
    }
  }
}

class TreatmentScheduleModal extends StatefulWidget {
  const TreatmentScheduleModal({super.key});

  @override
  State<TreatmentScheduleModal> createState() => _TreatmentScheduleModalState();
}

class _TreatmentScheduleModalState extends State<TreatmentScheduleModal> {
  List<TreatmentScheduleItem> _saved = [];
  final _drafts = [_DraftEntry()];
  bool _loading = true;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user!.id;
    final items = await TreatmentScheduleService.list(userId);
    if (mounted) {
      setState(() {
        _saved = items;
        _loading = false;
      });
    }
  }

  void _addDraft() {
    setState(() => _drafts.add(_DraftEntry()));
  }

  void _removeDraft(int index) {
    if (_drafts.length == 1) {
      _drafts.first.name.clear();
      _drafts.first.setDosesPerDay(1);
      _drafts.first.doseTimes = [const TimeOfDay(hour: 8, minute: 0)];
      setState(() {});
      return;
    }
    setState(() {
      _drafts.removeAt(index).dispose();
    });
  }

  Future<void> _pickTime(_DraftEntry draft, int index) async {
    if (index < 0 || index >= draft.doseTimes.length) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: draft.doseTimes[index],
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: C.accentPrimary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && index >= 0 && index < draft.doseTimes.length) {
      setState(() => draft.doseTimes[index] = picked);
    }
  }

  Future<void> _save() async {
    final userId = context.read<AuthProvider>().user!.id;
    final toSave = _drafts.where((d) => d.name.text.trim().isNotEmpty).toList();
    if (toSave.isEmpty) {
      setState(() => _error = context.l10n.treatmentEnterName);
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final permitted = await TreatmentNotificationService.ensurePermission();
      for (final draft in toSave) {
        await TreatmentScheduleService.save(
          userId: userId,
          name: draft.name.text,
          dosesPerDay: draft.dosesPerDay,
          doseTimes: draft.doseTimes,
        );
      }
      for (final d in _drafts) {
        d.dispose();
      }
      _drafts
        ..clear()
        ..add(_DraftEntry());
      await _load();
      if (mounted) {
        final l10n = context.l10n;
        if (!permitted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  l10n.treatmentNotifOff),
              backgroundColor: C.amber700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.treatmentSaved),
              backgroundColor: C.statusGood,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.treatmentSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem(TreatmentScheduleItem item) async {
    await TreatmentScheduleService.delete(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppModal(
      title: l10n.actionTreatmentSchedule,
      onClose: () => Navigator.pop(context),
      child: _loading
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator(color: C.accentPrimary)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error.isNotEmpty) ...[
                  AppBanner(
                    text: _error,
                    bg: C.red50,
                    border: C.red200,
                    fg: C.red700,
                    icon: Icons.error_outline,
                  ),
                  SizedBox(height: 16),
                ],
                if (_saved.isNotEmpty) ...[
                  Text(l10n.treatmentYourSchedule,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: C.gray700)),
                  SizedBox(height: 10),
                  ..._saved.map(_savedCard),
                  SizedBox(height: 20),
                  Divider(color: C.gray200),
                  SizedBox(height: 20),
                ],
                Text(l10n.treatmentAddMedicine,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: C.gray700)),
                SizedBox(height: 12),
                ...List.generate(_drafts.length, _draftCard),
                SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addDraft,
                  icon: Icon(Icons.add, size: 18, color: C.accentPrimary),
                  label: Text(l10n.treatmentAddAnother,
                      style: TextStyle(color: C.accentPrimary, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: C.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 20),
                PrimaryButton(
                  label: _saving ? l10n.treatmentSaving : l10n.treatmentSaveSchedule,
                  color: C.teal600,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }

  Widget _savedCard(TreatmentScheduleItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.gray100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.gray200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15, color: C.gray900)),
                SizedBox(height: 4),
                Text(
                  '${item.dosesPerDay}× daily · ${item.doseTimes.map(formatDoseTime).join(', ')}',
                  style: TextStyle(fontSize: 13, color: C.gray500),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteItem(item),
            icon: Icon(Icons.delete_outline, size: 20, color: C.gray400),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _draftCard(int index) {
    if (index < 0 || index >= _drafts.length) return const SizedBox.shrink();
    final l10n = context.l10n;
    final draft = _drafts[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _drafts.length > 1 ? l10n.treatmentEntryNumber(index + 1) : l10n.treatmentNewEntry,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: C.gray500),
                ),
              ),
              if (_drafts.length > 1)
                IconButton(
                  onPressed: () => _removeDraft(index),
                  icon: Icon(Icons.close, size: 18, color: C.gray400),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
          SizedBox(height: 10),
          Text(l10n.treatmentMedicineName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
          TextField(
            controller: draft.name,
            textCapitalization: TextCapitalization.sentences,
            decoration: appInput(l10n.treatmentMedicinePlaceholder),
          ),
          SizedBox(height: 16),
          Text(l10n.treatmentHowManyTimes,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: C.gray700)),
          SizedBox(height: 8),
          Row(
            children: [1, 2, 3].map((n) {
              final selected = draft.dosesPerDay == n;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: n < 3 ? 8 : 0),
                  child: InkWell(
                    onTap: () => setState(() => draft.setDosesPerDay(n)),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? C.navActiveBg : C.gray100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? C.navActiveBorder : C.gray200,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: selected ? C.navActiveFg : C.gray600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16),
          ...List.generate(draft.dosesPerDay, (i) {
            if (i < 0 || i >= draft.doseTimes.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.treatmentDoseTime(i + 1),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: C.gray700)),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: () => _pickTime(draft, i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: C.inputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.gray200.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 18, color: C.gray500),
                          SizedBox(width: 10),
                          Text(
                            formatDoseTime(draft.doseTimes[i]),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: C.gray900,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_drop_down, color: C.gray400),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
