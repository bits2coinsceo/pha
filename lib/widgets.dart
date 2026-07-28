import 'dart:math';
import 'package:flutter/material.dart';
import 'medical_guidelines.dart';
import 'theme.dart';

// ── Modal ────────────────────────────────────────────────────────────────────
/// Mirrors the web `Modal` component: centered card, max-w-md, header with title
/// and a close button, scrollable body.
class AppModal extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onClose;
  const AppModal({super.key, required this.title, required this.child, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.card,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: C.cardBorder.withValues(alpha: 0.45)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 448,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: C.cardBorder.withValues(alpha: 0.35))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: C.gray900)),
                  ),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, size: 20, color: C.gray600),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generic helpers ──────────────────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Widget? icon;
  /// When true, uses [kBlueTealGradient] instead of [color]-based gradient.
  final bool cosmicGradient;

  PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    Color? color,
    this.icon,
    this.cosmicGradient = false,
  }) : color = color ?? C.nebulaPurple;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: disabled
                  ? null
                  : (cosmicGradient
                      ? kBlueTealGradient
                      : LinearGradient(
                          colors: [color, Color.lerp(color, C.neonCyan, 0.35)!],
                        )),
              color: disabled ? C.gray200 : null,
              boxShadow: disabled ? null : C.glowShadow(),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: disabled ? C.gray400 : C.white,
                      height: 1.2,
                    ),
                  ),
                ),
                if (icon != null) ...[SizedBox(width: 8), icon!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration appInput(String hint, {Color? focus}) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: C.gray400, fontSize: 15),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: C.inputFill,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: C.gray200.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focus ?? C.accentFocus, width: 2),
      ),
    );

class AppBanner extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;
  final Color fg;
  final IconData? icon;
  const AppBanner({super.key, required this.text, required this.bg, required this.border, required this.fg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            SizedBox(width: 8),
          ],
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: fg))),
        ],
      ),
    );
  }
}

// ── Bottom navigation ────────────────────────────────────────────────────────
class AppBottomNav extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChange;
  const AppBottomNav({super.key, required this.current, required this.onChange});

  static const _items = [
    ('home', 'Home', Icons.home_outlined),
    ('history', 'History', Icons.access_time),
    ('insights', 'Insights', Icons.bar_chart),
    ('profile', 'Profile', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.card,
        border: Border(top: BorderSide(color: C.cardBorder.withValues(alpha: 0.35))),
        boxShadow: C.glowShadow(blur: 16, offset: Offset(0, -4), alphaDark: 0.27, alphaLight: 0.08),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _items.map((it) {
              final selected = current == it.$1;
              return InkWell(
                onTap: () => onChange(it.$1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? C.navActiveBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: selected ? Border.all(color: C.navActiveBorder, width: 1.5) : null,
                    boxShadow: selected ? C.glowShadow(blur: 8, alphaDark: 0.2, alphaLight: 0.06) : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(it.$3, size: 24, color: selected ? C.navActiveFg : C.gray500),
                      SizedBox(height: 4),
                      Text(it.$2,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? C.navActiveFg : C.gray500)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Health Index + daily steps (single overview card) ─────────────────────────
class HealthIndexCard extends StatelessWidget {
  final int score;
  final String status;
  final int steps;
  final int stepsGoal;
  final VoidCallback? onHealthIndexTap;

  const HealthIndexCard({
    super.key,
    required this.score,
    required this.status,
    required this.steps,
    this.stepsGoal = MedicalGuidelines.stepsGoal,
    this.onHealthIndexTap,
  });

  Color get _statusColor {
    switch (status.toLowerCase()) {
      case 'excellent':
      case 'good':
        return C.statusGood;
      case 'fair':
        return C.statusFair;
      case 'poor':
      case 'needs_attention':
        return C.statusPoor;
      default:
        return C.gray500;
    }
  }

  /// Ring + score use status color so danger (poor) reads red immediately.
  Color get _gaugeColor => _statusColor;

  String get _statusMessage => MedicalGuidelines.indexCardBlurb(status);

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final cap = normalized == 'poor' || normalized == 'needs_attention'
        ? 'Needs Attention'
        : status.isEmpty
            ? status
            : status[0].toUpperCase() + status.substring(1);
    final stepPct = (steps.toDouble() / stepsGoal.toDouble()).clamp(0.0, 1.0);
    final stepFeedback = stepsFeedbackFor(steps);
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(22),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onHealthIndexTap,
                  borderRadius: BorderRadius.circular(12),
                  child: _roundMetricColumn(
                    title: 'Health Index',
                    trailing: Icon(Icons.info_outline, size: 14, color: C.gray400),
                    fraction: score.toDouble() / 100,
                    progressColor: _gaugeColor,
                    centerMain: '$score',
                    centerSub: '/100',
                    centerMainSize: 30,
                    centerMainColor: _gaugeColor,
                    belowGauge: Column(
                      children: [
                        Text(cap,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: _statusColor)),
                        SizedBox(height: 4),
                        Text(_statusMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: C.gray500, fontSize: 13, height: 1.3)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: C.gray200),
            Expanded(
              child: _roundMetricColumn(
                title: 'Steps',
                trailing: Icon(Icons.directions_walk, size: 14, color: C.statusGood),
                fraction: stepPct,
                progressColor: C.progressGreen,
                centerMain: _fmt(steps),
                centerSub: '/${_fmt(stepsGoal)}',
                centerMainSize: _fmt(steps).length > 5 ? 20 : 28,
                belowGauge: Column(
                  children: [
                    Text(stepFeedback.range,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: C.statusGood,
                            height: 1.2)),
                    SizedBox(height: 6),
                    Text(stepFeedback.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: C.gray500, fontSize: 11, height: 1.35)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundMetricColumn({
    required String title,
    required Widget trailing,
    required double fraction,
    required Color progressColor,
    required String centerMain,
    required String centerSub,
    required double centerMainSize,
    required Widget belowGauge,
    Color? centerMainColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    color: C.gray500, fontWeight: FontWeight.w500, fontSize: 13)),
            SizedBox(width: 6),
            trailing,
          ],
        ),
        SizedBox(height: 12),
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _GaugePainter(fraction, progressColor: progressColor),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centerMain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: centerMainSize,
                          fontWeight: FontWeight.bold,
                          color: centerMainColor ?? C.gray900)),
                  Text(centerSub, style: TextStyle(fontSize: 12, color: C.gray500)),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 14),
        belowGauge,
      ],
    );
  }
}

class _StepsFeedback {
  final String range;
  final String message;
  const _StepsFeedback({required this.range, required this.message});
}

_StepsFeedback stepsFeedbackFor(int steps) {
  final f = StepsGuidelines.feedback(steps);
  return _StepsFeedback(range: f.range, message: f.message);
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color? progressColor;
  _GaugePainter(this.fraction, {this.progressColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * (45 / 60);
    final track = Paint()
      ..color = C.gaugeTrack
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    final progress = Paint()
      ..color = progressColor ?? C.progressMint
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * fraction.clamp(0, 1),
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.progressColor != progressColor;
}

String _fmt(num n) {
  final s = n.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String fmtThousands(num n) => _fmt(n);

// ── Metrics grid ─────────────────────────────────────────────────────────────
class MetricsGrid extends StatelessWidget {
  final num calories;
  final num distance;
  final num activeTime;
  final String distanceUnit;
  const MetricsGrid({
    super.key,
    required this.calories,
    required this.distance,
    required this.activeTime,
    this.distanceUnit = 'km',
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.local_fire_department, 'Calories', calories, 'kcal', C.orange500),
      (Icons.place, 'Distance', distance, distanceUnit, C.blue500),
      (Icons.access_time, 'Active Time', activeTime, 'min', C.teal600),
    ];
    return Row(
      children: items.map((it) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              decoration: cardDecoration(radius: 12),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(it.$1, size: 24, color: it.$5),
                  SizedBox(height: 12),
                  Text('${it.$3}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
                  SizedBox(height: 4),
                  Text(it.$4, style: TextStyle(fontSize: 12, color: C.gray500)),
                  SizedBox(height: 8),
                  Text(it.$2,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500, color: C.gray600)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Quick actions ────────────────────────────────────────────────────────────
class QuickAction {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool locked;
  final bool comingSoon;
  final ({int used, int total})? credits;
  final VoidCallback onTap;

  QuickAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.locked = false,
    this.comingSoon = false,
    this.credits,
    required this.onTap,
  });
}

class QuickActions extends StatelessWidget {
  final List<QuickAction> actions;
  final VoidCallback onUpgrade;
  const QuickActions({super.key, required this.actions, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Actions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: C.gray900,
                  shadows: C.textGlow(),
                )),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    gradient: kAmberGradient, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: C.white),
                    SizedBox(width: 6),
                    Text('PHA Plus+',
                        style: TextStyle(
                            color: C.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        ...actions.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActionTile(action: a, onUpgrade: onUpgrade),
            )),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onUpgrade;
  const _ActionTile({required this.action, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final a = action;
    final remaining = a.credits != null ? a.credits!.total - a.credits!.used : null;
    final exhausted = remaining != null && remaining <= 0;

    if (a.comingSoon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: cardDecoration(radius: 16),
        child: Opacity(
          opacity: 0.85,
          child: Row(
            children: [
              _iconBox(a.icon, a.bgColor, a.color),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(a.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: C.gray900,
                                  height: 1.25)),
                        ),
                        SizedBox(width: 8),
                        _pill('Coming Soon', C.sky50, C.sky200, C.sky500, Icons.access_time),
                      ],
                    ),
                    Text(a.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: C.gray500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final blocked = a.locked || exhausted;
    return InkWell(
      onTap: blocked ? onUpgrade : a.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: cardDecoration(radius: 16),
        child: Row(
          children: [
            _iconBox(a.icon, a.locked ? C.gray200 : a.bgColor, a.locked ? C.gray400 : a.color),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(a.title,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: a.locked ? C.gray600 : C.gray900)),
                      ),
                      if (a.locked) ...[
                        SizedBox(width: 8),
                        _pill('Plus+', C.amber50, C.amber200, C.amber300, Icons.lock),
                      ],
                    ],
                  ),
                  Text(a.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: C.gray500)),
                ],
              ),
            ),
            if (!a.locked && a.credits != null) _creditsBadge(a.credits!, remaining!, exhausted),
            SizedBox(width: 8),
            Icon(blocked ? Icons.auto_awesome : Icons.arrow_forward,
                size: 16, color: blocked ? C.amber300 : C.neonCyan),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon, Color bg, Color fg) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: fg),
      );

  Widget _pill(String text, Color bg, Color border, Color fg, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: fg),
            SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _creditsBadge(({int used, int total}) credits, int remaining, bool exhausted) {
    final color = exhausted ? C.red400 : remaining == 1 ? C.amber500 : C.gray400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: List.generate(credits.total, (i) {
            if (i < 0 || i >= credits.total) return const SizedBox.shrink();
            final filled = i < remaining;
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? (exhausted ? C.red300 : remaining == 1 ? C.amber400 : C.blue400)
                      : C.gray200,
                ),
              ),
            );
          }),
        ),
        SizedBox(width: 2),
        Text('${exhausted ? 0 : remaining}/${credits.total}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
      ],
    );
  }
}

// ── Health metrics chart (line) ──────────────────────────────────────────────
class ChartData {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final List<double> trend;
  ChartData(this.label, this.value, this.unit, this.color, this.trend);
}

class HealthMetricsChart extends StatelessWidget {
  final List<ChartData> metrics;
  const HealthMetricsChart({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Metrics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: C.gray900)),
          SizedBox(height: 24),
          ...metrics.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration:
                      BoxDecoration(color: C.gray100, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m.label,
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500, color: C.gray500)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(m.value,
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold, color: C.gray900)),
                              if (m.unit.isNotEmpty) ...[
                                SizedBox(width: 4),
                                Text(m.unit,
                                    style: TextStyle(fontSize: 12, color: C.gray400)),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (m.trend.length > 1) ...[
                        SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _LinePainter(m.trend, m.color.withValues(alpha: 0.6)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> trend;
  final Color color;
  _LinePainter(this.trend, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.length < 2) return;
    final minV = trend.fold(trend.first, (double a, double b) => a < b ? a : b);
    final maxV = trend.fold(trend.first, (double a, double b) => a > b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final path = Path();
    for (var i = 0; i < trend.length; i++) {
      final x = i / (trend.length - 1) * size.width;
      final y = size.height - (trend[i] - minV) / range * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.trend != trend;
}

// ── Mini bar chart (insights) ────────────────────────────────────────────────
double _chartMax(List<double> values) =>
    values.fold(values.first, (double a, double b) => a > b ? a : b);

double _chartMin(List<double> values) =>
    values.fold(values.first, (double a, double b) => a < b ? a : b);

class MiniBarChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  const MiniBarChart({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Text('No data', style: TextStyle(fontSize: 12, color: C.gray400));
    }
    final maxV = _chartMax(values);
    final minV = _chartMin(values);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final h = (((v - minV) / range) * 36 + 8).clamp(8.0, 44.0).toDouble();
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                height: h,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Line chart with light horizontal grid (Health History steps trend).
class MiniLineChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  final int gridLines;

  const MiniLineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 140,
    this.gridLines = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data', style: TextStyle(fontSize: 12, color: C.gray400)),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _GridLinePainter(
          values: values,
          color: color,
          gridColor: C.gray200,
          gridLines: gridLines,
        ),
      ),
    );
  }
}

class _GridLinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color gridColor;
  final int gridLines;

  _GridLinePainter({
    required this.values,
    required this.color,
    required this.gridColor,
    required this.gridLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final lines = gridLines.clamp(2, 12);
    for (var i = 0; i < lines; i++) {
      final y = size.height * i / (lines - 1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length < 2) {
      // Single point — draw a flat mid line hint.
      if (values.length == 1) {
        final y = size.height * 0.5;
        canvas.drawCircle(Offset(size.width * 0.5, y), 3, Paint()..color = color);
      }
      return;
    }

    final maxV = values.fold<double>(0, (a, b) => a > b ? a : b);
    // Always pin floor at 0 so empty days sit on the baseline.
    final minV = 0.0;
    final range = maxV <= minV ? 1.0 : maxV - minV;
    final padY = 4.0;
    final usableH = size.height - padY * 2;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = padY + usableH - (values[i] - minV) / range * usableH;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _GridLinePainter old) =>
      old.values != values ||
      old.color != color ||
      old.gridColor != gridColor ||
      old.gridLines != gridLines;
}
