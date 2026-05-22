import 'dart:math';
import 'package:flutter/material.dart';
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
      backgroundColor: C.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.gray200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: C.gray900)),
                  ),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
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
  const PrimaryButton({super.key, required this.label, this.onPressed, this.color = C.blue500, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: C.gray200,
          foregroundColor: C.white,
          disabledForegroundColor: C.gray400,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (icon != null) ...[const SizedBox(width: 6), icon!],
          ],
        ),
      ),
    );
  }
}

InputDecoration appInput(String hint, {Color focus = C.blue500}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: C.gray400),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: C.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: C.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focus, width: 2),
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
            const SizedBox(width: 8),
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
      decoration: const BoxDecoration(
        color: C.white,
        border: Border(top: BorderSide(color: C.gray200)),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
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
                    color: selected ? C.blue50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(it.$3, size: 24, color: selected ? C.blue600 : C.gray600),
                      const SizedBox(height: 4),
                      Text(it.$2,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: selected ? C.blue600 : C.gray600)),
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

// ── Health Index card (circular gauge) ───────────────────────────────────────
class HealthIndexCard extends StatelessWidget {
  final int score;
  final String status;
  const HealthIndexCard({super.key, required this.score, required this.status});

  Color get _statusColor {
    switch (status.toLowerCase()) {
      case 'good':
        return C.green500;
      case 'fair':
        return C.yellow500;
      case 'poor':
        return C.red500;
      default:
        return C.gray500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cap = status.isEmpty ? status : status[0].toUpperCase() + status.substring(1);
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('Health Index', style: TextStyle(color: C.gray600, fontWeight: FontWeight.w500)),
              SizedBox(width: 8),
              Icon(Icons.info_outline, size: 16, color: C.gray400),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: CustomPaint(
                  painter: _GaugePainter(score / 100),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$score',
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.bold, color: C.gray900)),
                        const Text('/100', style: TextStyle(fontSize: 12, color: C.gray500)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cap, style: TextStyle(fontWeight: FontWeight.w600, color: _statusColor)),
                    const SizedBox(height: 8),
                    const Text("You're doing great!",
                        style: TextStyle(color: C.gray600, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  _GaugePainter(this.fraction);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * (45 / 60);
    final track = Paint()
      ..color = C.gray200
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    final progress = Paint()
      ..color = C.emerald500
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
  bool shouldRepaint(_GaugePainter old) => old.fraction != fraction;
}

// ── Steps card ───────────────────────────────────────────────────────────────
class StepsCard extends StatelessWidget {
  final int current;
  final int goal;
  const StepsCard({super.key, required this.current, required this.goal});

  @override
  Widget build(BuildContext context) {
    final pct = (current / goal).clamp(0.0, 1.0);
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.green100, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.directions_walk, size: 24, color: C.green600),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Steps', style: TextStyle(fontWeight: FontWeight.w600, color: C.gray900)),
                  Text('${(pct * 100).round()}% of daily goal',
                      style: const TextStyle(fontSize: 14, color: C.gray500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_fmt(current),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: C.gray900)),
              const SizedBox(width: 8),
              Text('/${_fmt(goal)}', style: const TextStyle(fontSize: 14, color: C.gray500)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: C.gray200,
              valueColor: const AlwaysStoppedAnimation(C.green500),
            ),
          ),
        ],
      ),
    );
  }
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
                  const SizedBox(height: 12),
                  Text('${it.$3}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
                  const SizedBox(height: 4),
                  Text(it.$4, style: const TextStyle(fontSize: 12, color: C.gray500)),
                  const SizedBox(height: 8),
                  Text(it.$2,
                      style: const TextStyle(
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
            const Text('Quick Actions',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: C.gray900)),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    gradient: kAmberGradient, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
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
        const SizedBox(height: 16),
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
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.gray200, style: BorderStyle.solid),
        ),
        child: Opacity(
          opacity: 0.7,
          child: Row(
            children: [
              _iconBox(a.icon, a.bgColor, a.color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(a.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14, color: C.gray500)),
                        ),
                        const SizedBox(width: 8),
                        _pill('Coming Soon', C.sky50, C.sky200, C.sky600, Icons.access_time),
                      ],
                    ),
                    Text(a.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: C.gray400)),
                  ],
                ),
              ),
              const Icon(Icons.access_time, size: 16, color: C.gray300),
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
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: blocked ? C.gray200 : C.gray100),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            _iconBox(a.icon, a.locked ? C.gray100 : a.bgColor, a.locked ? C.gray400 : a.color),
            const SizedBox(width: 16),
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
                                color: a.locked ? C.gray500 : C.gray900)),
                      ),
                      if (a.locked) ...[
                        const SizedBox(width: 8),
                        _pill('Plus+', C.amber50, C.amber200, C.amber600, Icons.lock),
                      ],
                    ],
                  ),
                  Text(a.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: C.gray500)),
                ],
              ),
            ),
            if (!a.locked && a.credits != null) _creditsBadge(a.credits!, remaining!, exhausted),
            const SizedBox(width: 8),
            Icon(blocked ? Icons.auto_awesome : Icons.arrow_forward,
                size: 16, color: blocked ? C.amber400 : C.blue400),
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
            const SizedBox(width: 4),
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
        const SizedBox(width: 2),
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
          const Text('Health Metrics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: C.gray900)),
          const SizedBox(height: 24),
          ...metrics.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration:
                      BoxDecoration(color: C.gray50, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m.label,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500, color: C.gray500)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(m.value,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold, color: C.gray900)),
                              if (m.unit.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(m.unit,
                                    style: const TextStyle(fontSize: 12, color: C.gray400)),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (m.trend.length > 1) ...[
                        const SizedBox(height: 8),
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
    final minV = trend.reduce(min);
    final maxV = trend.reduce(max);
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
class MiniBarChart extends StatelessWidget {
  final List<num> values;
  final Color color;
  const MiniBarChart({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Text('No data', style: TextStyle(fontSize: 12, color: C.gray400));
    }
    final maxV = values.reduce(max);
    final minV = values.reduce(min);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final h = (((v - minV) / range) * 36 + 8).clamp(8.0, 44.0);
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
