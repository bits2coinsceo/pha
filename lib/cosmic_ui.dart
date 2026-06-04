import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Deep-space backdrop with nebula glow and star field.
class CosmicBackground extends StatelessWidget {
  final Animation<double>? drift;
  const CosmicBackground({super.key, this.drift});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: drift ?? const AlwaysStoppedAnimation(0),
      builder: (_, __) {
        final t = drift?.value ?? 0;
        return Container(
          decoration: BoxDecoration(gradient: cosmicSpaceGradient),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _StarfieldPainter()),
              Container(color: C.isDark ? const Color(0x9906041A) : const Color(0x55FFFFFF)),
              Positioned(
                top: -80 + t * 24,
                right: -60,
                child: _nebulaOrb(220, C.nebulaPink.withValues(alpha: 0.12)),
              ),
              Positioned(
                bottom: 40 - t * 18,
                left: -90,
                child: _nebulaOrb(280, C.nebulaBlue.withValues(alpha: 0.1)),
              ),
              Positioned(
                top: 180 + t * 12,
                left: 30,
                child: _nebulaOrb(120, C.neonCyan.withValues(alpha: 0.08)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _nebulaOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  static final _stars = List.generate(90, (i) {
    final r = Random(i * 997);
    return (
      x: r.nextDouble(),
      y: r.nextDouble(),
      size: r.nextDouble() * 1.8 + 0.4,
      alpha: r.nextDouble() * 0.5 + 0.25,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _stars) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: s.alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// App shell with cosmic background.
class CosmicScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Animation<double>? backgroundDrift;

  const CosmicScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundDrift,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.gray50,
      appBar: appBar,
      extendBodyBehindAppBar: appBar != null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CosmicBackground(drift: backgroundDrift),
          body,
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Glass panel for quest cards and forms.
class CosmicPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const CosmicPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: cosmicPanelDecoration(radius: radius),
      child: child,
    );
  }
}

/// Glowing section title for gaming HUD feel.
class CosmicSectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;

  const CosmicSectionTitle(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: C.neonCyan),
          SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: C.gray900,
            letterSpacing: 0.5,
            shadows: [Shadow(color: Color(0x6600D4FF), blurRadius: 12)],
          ),
        ),
      ],
    );
  }
}
