import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../db.dart';
import '../theme.dart';
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

List<_Block> get _blocks => [
  _Block('Block 1', 'Stress Awareness', _blue, [
    _Question('How often have you felt overwhelmed or unable to control important things in your life?'),
    _Question('How often do you experience physical symptoms like headaches, muscle tension, or fatigue due to stress?'),
    _Question('How well have you been sleeping?'),
    _Question('How often do you feel anxious, worried, or on edge?'),
    _Question('How satisfied are you with your ability to relax and unwind?'),
  ]),
  _Block('Block 2', 'Physical Symptoms', _orange, [
    _Question('Do you often have:', ['Headaches', 'Muscle spasms', 'Neck pain', 'Chest pressure', 'Heaviness in the stomach']),
    _Question('Do your symptoms get worse after stress?'),
    _Question('Do you have:', ['Tachycardia', 'Blood pressure surges', 'Sweating', 'Trembling']),
    _Question('Do you have any gastrointestinal problems:', ['Bloating', 'Heartburn', 'Spasms', 'Diarrhea / constipation']),
    _Question('Do you feel short of breath?'),
    _Question('Do you have chronic fatigue?'),
    _Question('Do you have muscle tension?'),
    _Question('Do your symptoms get worse during conflicts or anxiety?'),
  ]),
  _Block('Block 3', 'Behavioral Profile', _teal, [
    _Question('Do you tend to:', ['Keep everything under control', 'Avoid conflicts', 'Accumulate emotions', 'Take responsibility for everyone']),
    _Question('Do you often:', ['Work overtime', "Don't rest", 'Feel guilty']),
    _Question('Is it difficult for you to say "no"?'),
    _Question('Do you have a fear of losing control?'),
    _Question('Do you experience constant internal tension even in a calm environment?'),
    _Question('Do you feel loneliness despite communication?'),
    _Question('Do you often "keep everything inside"?'),
  ]),
];

const _answerOptions = [('Never', 0), ('Sometimes', 1), ('Often', 2)];

int _scorePercent(List<int> answers, int questionCount) {
  if (answers.isEmpty) return 0;
  final sum = answers.fold(0, (a, b) => a + b);
  return ((sum / (questionCount * 2)) * 100).round();
}

({String label, Color color, Color bg, Color border, String desc}) _level(int score) {
  if (score >= 67) {
    return (
      label: 'High',
      color: C.red600,
      bg: C.red50,
      border: C.red200,
      desc: 'Your results indicate significant stress and psychosomatic tension. Consider speaking with a specialist and taking steps to reduce your load.'
    );
  }
  if (score >= 34) {
    return (
      label: 'Moderate',
      color: C.amber600,
      bg: C.amber50,
      border: C.amber200,
      desc: 'You are experiencing a moderate level of stress. Pay attention to rest, relaxation routines, and setting healthy boundaries.'
    );
  }
  return (
    label: 'Low',
    color: C.emerald600,
    bg: C.emerald50,
    border: C.emerald200,
    desc: 'Your stress and psychosomatic indicators are within a healthy range. Keep maintaining your wellness habits.'
  );
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

  int get _totalQuestions => _blocks.fold(0, (a, b) => a + b.questions.length);

  Future<void> _answer(int value) async {
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
      'level': _level(total).label,
      'answers': jsonEncode(answers),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
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
                Text('PsychoTest',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: C.gray900)),
                Text('Stress & Psychosomatic Self-Assessment',
                    style: TextStyle(fontSize: 14, color: C.gray500)),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),
        Text(
          'This assessment contains 3 blocks with a total of $_totalQuestions questions. Answer honestly — there are no right or wrong answers. Results are saved to your profile.',
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
                    Text('${b.questions.length} questions',
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
          child: Text('Each question has 3 answer options: Never · Sometimes · Often',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: C.gray500)),
        ),
        SizedBox(height: 16),
        PrimaryButton(
          label: 'Start Assessment',
          color: C.teal500,
          icon: Icon(Icons.chevron_right, size: 16, color: C.white),
          onPressed: () => setState(() => phase = 'block'),
        ),
      ],
    );
  }

  Widget _question() {
    final block = _blocks[blockIndex];
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
            Text('Q${questionIndex + 1} of ${block.questions.length}',
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
        ..._answerOptions.map((opt) => Padding(
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
    final r = result!;
    final lvl = _level(r.total);
    final blockScores = [
      ('Stress Awareness', r.b1, _blue.dot),
      ('Physical Symptoms', r.b2, _orange.dot),
      ('Behavioral Profile', r.b3, _teal.dot),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text('YOUR RESULT',
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
          child: Text('${lvl.label} Stress Level',
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
                    Text('Retake', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                label: 'Done',
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
