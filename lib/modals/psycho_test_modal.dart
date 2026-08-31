import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../db.dart';
import '../health_index.dart';
import '../medical_guidelines.dart';
import '../theme.dart';
import '../l10n/l10n_ext.dart';
import '../l10n/medical_l10n.dart';
import '../widgets.dart';

const _uuid = Uuid();

class _Question {
  final String text;
  final List<String>? subItems;
  const _Question(this.text, [this.subItems]);
}

class _Block {
  final String title;
  final String subtitle;
  final ({Color bg, Color border, Color text, Color pillBg, Color pillText, Color dot}) color;
  final List<_Question> questions;
  const _Block(this.title, this.subtitle, this.color, this.questions);
}

({Color bg, Color border, Color text, Color pillBg, Color pillText, Color dot}) get _blue => (
  bg: C.blue50,
  border: C.blue200,
  text: C.blue700,
  pillBg: C.blue100,
  pillText: C.blue700,
  dot: C.blue500
);
({Color bg, Color border, Color text, Color pillBg, Color pillText, Color dot}) get _orange => (
  bg: C.orange50,
  border: Color(0xFFFED7AA),
  text: Color(0xFFC2410C),
  pillBg: C.orange100,
  pillText: Color(0xFFC2410C),
  dot: C.orange500
);
({Color bg, Color border, Color text, Color pillBg, Color pillText, Color dot}) get _teal => (
  bg: C.teal50,
  border: C.teal200,
  text: C.teal700,
  pillBg: C.teal100,
  pillText: C.teal700,
  dot: C.teal500
);

List<_Block> _blocksFor(AppLocalizations l10n) => [
  _Block(l10n.psychoBlock1Title, l10n.psychoBlock1Subtitle, _blue, [
    _Question(l10n.psychoQ1),
    _Question(l10n.psychoQ2),
    _Question(l10n.psychoQ3),
    _Question(l10n.psychoQ4),
    _Question(l10n.psychoQ5),
  ]),
  _Block(l10n.psychoBlock2Title, l10n.psychoBlock2Subtitle, _orange, [
    _Question(l10n.psychoQ6, [l10n.psychoSubHeadaches, l10n.psychoSubMuscleSpasms, l10n.psychoSubNeckPain, l10n.psychoSubChestPressure, l10n.psychoSubStomachHeaviness]),
    _Question(l10n.psychoQ7),
    _Question(l10n.psychoQ8, [l10n.psychoSubTachycardia, l10n.psychoSubBpSurges, l10n.psychoSubSweating, l10n.psychoSubTrembling]),
    _Question(l10n.psychoQ9, [l10n.psychoSubBloating, l10n.psychoSubHeartburn, l10n.psychoSubSpasms, l10n.psychoSubDiarrheaConstipation]),
    _Question(l10n.psychoQ10),
    _Question(l10n.psychoQ11),
    _Question(l10n.psychoQ12),
    _Question(l10n.psychoQ13),
  ]),
  _Block(l10n.psychoBlock3Title, l10n.psychoBlock3Subtitle, _teal, [
    _Question(l10n.psychoQ14, [l10n.psychoSubKeepControl, l10n.psychoSubAvoidConflicts, l10n.psychoSubAccumulateEmotions, l10n.psychoSubTakeResponsibility]),
    _Question(l10n.psychoQ15, [l10n.psychoSubWorkOvertime, l10n.psychoSubDontRest, l10n.psychoSubFeelGuilty]),
    _Question(l10n.psychoQ16),
    _Question(l10n.psychoQ17),
    _Question(l10n.psychoQ18),
    _Question(l10n.psychoQ19),
    _Question(l10n.psychoQ20),
  ]),
];

int _scorePercent(List<int> answers, int questionCount) {
  if (answers.isEmpty) return 0;
  final sum = answers.fold(0, (a, b) => a + b);
  return ((sum / (questionCount * 2)) * 100).round();
}

({String label, Color color, Color bg, Color border, String desc}) _level(int score, AppLocalizations l10n) {
  final c = PsychoGuidelines.classifyLoad(score);
  switch (c.band) {
    case 'high':
      return (
        label: l10n.psychoHigh,
        color: C.red600,
        bg: C.red50,
        border: C.red200,
        desc: l10n.psychoHighMsg,
      );
    case 'moderate':
      return (
        label: l10n.psychoModerate,
        color: C.amber600,
        bg: C.amber50,
        border: C.amber200,
        desc: l10n.psychoModerateMsg,
      );
    default:
      return (
        label: l10n.psychoLow,
        color: C.emerald600,
        bg: C.emerald50,
        border: C.emerald200,
        desc: l10n.psychoLowMsg,
      );
  }
}

class PsychoTestModal extends StatefulWidget {
  const PsychoTestModal({super.key});

  @override
  State<PsychoTestModal> createState() => _PsychoTestModalState();
}

class _PsychoTestModalState extends State<PsychoTestModal> {
  String phase = 'intro'; // intro | block | result
  int blockIndex = 0;
  int questionIndex = 0;
  final answers = <List<int>>[[], [], []];
  bool saving = false;
  ({int b1, int b2, int b3, int total})? result;

  List<_Block> get _blocks => _blocksFor(context.l10n);

  int get _totalQuestions => _blocks.fold(0, (a, b) => a + b.questions.length);

  Future<void> _answer(int value) async {
    if (blockIndex < 0 || blockIndex >= _blocks.length) return;
    if (blockIndex >= answers.length) return;
    answers[blockIndex].add(value);
    final block = _blocks[blockIndex];
    final lastQuestion = questionIndex == block.questions.length - 1;
    final lastBlock = blockIndex == _blocks.length - 1;
    if (!lastQuestion) {
      setState(() => questionIndex++);
      return;
    }
    if (!lastBlock) {
      setState(() {
        blockIndex++;
        questionIndex = 0;
      });
      return;
    }
    setState(() => saving = true);
    final b1 = _scorePercent(answers[0], _blocks[0].questions.length);
    final b2 = _scorePercent(answers[1], _blocks[1].questions.length);
    final b3 = _scorePercent(answers[2], _blocks[2].questions.length);
    final total = ((b1 + b2 + b3) / 3).round();
    final auth = context.read<AuthProvider>();
    await Db.instance.raw.insert('psychotest_results', {
      'id': _uuid.v4(),
      'user_id': auth.user!.id,
      'block1_score': b1,
      'block2_score': b2,
      'block3_score': b3,
      'total_score': total,
      'level': _level(total, context.l10n).label,
      'answers': jsonEncode(answers),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await HealthIndexService.recalculate(auth.user!.id);
    setState(() {
      result = (b1: b1, b2: b2, b3: b3, total: total);
      phase = 'result';
      saving = false;
    });
  }

  void _restart() {
    setState(() {
      phase = 'intro';
      blockIndex = 0;
      questionIndex = 0;
      answers[0] = [];
      answers[1] = [];
      answers[2] = [];
      result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      title: '',
      onClose: () => Navigator.pop(context),
      child: phase == 'intro'
          ? _intro()
          : phase == 'block'
              ? _question()
              : _result(),
    );
  }

  Widget _intro() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(color: C.teal100, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.psychology, color: C.teal600, size: 24),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.actionPsychoTest,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: C.gray900)),
                Text(l10n.psychoTestSubtitle,
                    style: TextStyle(fontSize: 14, color: C.gray500)),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),
        Text(
          l10n.psychoTestIntro,
          style: TextStyle(fontSize: 14, color: C.gray600, height: 1.5),
        ),
        SizedBox(height: 16),
        ..._blocks.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: b.color.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: b.color.border),
                ),
                child: Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(color: b.color.dot, shape: BoxShape.circle)),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.title.toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: b.color.text)),
                        Text(b.subtitle,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: C.gray800)),
                      ],
                    ),
                    Spacer(),
                    Text(l10n.psychoQuestionsCount(b.questions.length),
                        style: TextStyle(fontSize: 12, color: C.gray400)),
                  ],
                ),
              ),
            )),
        SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: C.gray50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.gray100),
          ),
          child: Text(l10n.psychoAnswerHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: C.gray500)),
        ),
        SizedBox(height: 16),
        PrimaryButton(
          label: l10n.psychoStartAssessment,
          color: C.teal500,
          icon: Icon(Icons.chevron_right, size: 16, color: C.white),
          onPressed: () => setState(() => phase = 'block'),
        ),
      ],
    );
  }

  Widget _question() {
    final l10n = context.l10n;
    final answerOptions = [
      (l10n.psychoNever, 0),
      (l10n.psychoSometimes, 1),
      (l10n.psychoOften, 2),
    ];
    if (blockIndex < 0 || blockIndex >= _blocks.length) {
      return const SizedBox.shrink();
    }
    final block = _blocks[blockIndex];
    if (questionIndex < 0 || questionIndex >= block.questions.length) {
      return const SizedBox.shrink();
    }
    final question = block.questions[questionIndex];
    final answeredSoFar =
        answers.take(blockIndex).fold(0, (a, l) => a + l.length) + questionIndex;
    final progress = answeredSoFar / _totalQuestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${block.title} — ${block.subtitle}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: block.color.text)),
            Text('${answeredSoFar + 1}/$_totalQuestions',
                style: TextStyle(fontSize: 12, color: C.gray400)),
          ],
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: C.gray100,
            valueColor: AlwaysStoppedAnimation(block.color.dot),
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: block.color.pillBg, borderRadius: BorderRadius.circular(99)),
              child: Text(block.subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: block.color.pillText)),
            ),
            SizedBox(width: 8),
            Text(context.l10n.psychoQuestionOfBlock(questionIndex + 1, block.questions.length),
                style: TextStyle(fontSize: 12, color: C.gray400)),
          ],
        ),
        SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: block.color.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: block.color.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question.text,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: C.gray900)),
              if (question.subItems != null) ...[
                SizedBox(height: 12),
                ...question.subItems!.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: block.color.dot, shape: BoxShape.circle)),
                          SizedBox(width: 8),
                          Text(item,
                              style: TextStyle(fontSize: 12, color: C.gray600)),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        SizedBox(height: 16),
        ...answerOptions.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: saving ? null : () => _answer(opt.$2),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.gray200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(opt.$1,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: C.gray800)),
                      Icon(Icons.chevron_right, size: 16, color: C.gray300),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _result() {
    final l10n = context.l10n;
    final r = result!;
    final lvl = _level(r.total, l10n);
    final blockScores = [
      (l10n.psychoBlock1Subtitle, r.b1, _blue.dot),
      (l10n.psychoBlock2Subtitle, r.b2, _orange.dot),
      (l10n.psychoBlock3Subtitle, r.b3, _teal.dot),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(l10n.psychoYourResult,
              style: TextStyle(
                  fontSize: 11, color: C.gray400, letterSpacing: 2)),
        ),
        SizedBox(height: 12),
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: lvl.bg,
              shape: BoxShape.circle,
              border: Border.all(color: lvl.border, width: 4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${r.total}',
                    style: TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold, color: lvl.color)),
                Text('/100', style: TextStyle(fontSize: 12, color: C.gray400)),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        Center(
          child: Text(l10n.psychoStressLevelTitle(lvl.label),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: lvl.color)),
        ),
        SizedBox(height: 4),
        Text(lvl.desc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: C.gray500, height: 1.4)),
        SizedBox(height: 20),
        ...blockScores.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                      width: 130,
                      child: Text(b.$1,
                          style: TextStyle(fontSize: 12, color: C.gray500))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: b.$2 / 100,
                        minHeight: 8,
                        backgroundColor: C.gray100,
                        valueColor: AlwaysStoppedAnimation(b.$3),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                      width: 32,
                      child: Text('${b.$2}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: C.gray700))),
                ],
              ),
            )),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _restart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.gray600,
                  side: BorderSide(color: C.gray200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 14),
                    SizedBox(width: 6),
                    Text(l10n.psychoRetake, style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                label: l10n.done,
                color: C.teal500,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
