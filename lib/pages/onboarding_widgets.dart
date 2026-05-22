import 'package:flutter/material.dart';

import '../theme.dart';

/// Gamified HUD: level, XP, health power meter.
class OnboardingGameHud extends StatelessWidget {
  final int xp;
  final int level;
  final String levelTitle;
  final double power; // 0..1
  final int streak;

  const OnboardingGameHud({
    super.key,
    required this.xp,
    required this.level,
    required this.levelTitle,
    required this.power,
    this.streak = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: kBlueTealGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _levelOrb(level),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lv $level · $levelTitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: C.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    Text('$streak-day streak · Health Power',
                        style: TextStyle(
                            color: C.white.withValues(alpha: 0.8), fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _xpPill(xp),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: power),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: C.white.withValues(alpha: 0.25),
                color: C.amber400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelOrb(int level) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: C.white.withValues(alpha: 0.2),
        border: Border.all(color: C.white.withValues(alpha: 0.45), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text('$level',
          style: const TextStyle(
              color: C.white, fontWeight: FontWeight.w900, fontSize: 14)),
    );
  }

  Widget _xpPill(int xp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: C.amber400,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 12, color: C.gray900),
          const SizedBox(width: 3),
          Text('$xp',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 11, color: C.gray900)),
        ],
      ),
    );
  }
}

class OnboardingQuestTrail extends StatelessWidget {
  final int currentStep;
  final bool quest1Done;
  final bool quest2Done;
  final bool quest3Done;

  const OnboardingQuestTrail({
    super.key,
    required this.currentStep,
    required this.quest1Done,
    required this.quest2Done,
    required this.quest3Done,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _node(1, 'Units', quest1Done, currentStep >= 1),
        _connector(quest1Done),
        _node(2, 'Basics', quest2Done, currentStep >= 2),
        _connector(quest2Done),
        _node(3, 'Boost', quest3Done, currentStep >= 3),
      ],
    );
  }

  Widget _connector(bool done) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: done
              ? kBlueTealGradient
              : null,
          color: done ? null : C.gray200,
        ),
      ),
    );
  }

  Widget _node(int n, String label, bool done, bool active) {
    final color = done ? C.teal500 : (active ? C.blue500 : C.gray300);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? C.teal50 : (active ? C.blue50 : C.gray100),
            border: Border.all(color: color, width: 2),
            boxShadow: active && !done
                ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)]
                : null,
          ),
          child: Icon(
            done ? Icons.check : Icons.flag,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? C.gray800 : C.gray400)),
      ],
    );
  }
}

class OnboardingBadgeStrip extends StatelessWidget {
  final List<({String emoji, String label, bool unlocked})> badges;

  const OnboardingBadgeStrip({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: badges
          .map((b) => Opacity(
                opacity: b.unlocked ? 1 : 0.35,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: b.unlocked ? C.amber50 : C.gray100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: b.unlocked ? C.amber300 : C.gray200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(b.label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: b.unlocked ? C.amber700 : C.gray400)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class OnboardingXpToast extends StatelessWidget {
  final String message;
  final int xp;

  const OnboardingXpToast({super.key, required this.message, required this.xp});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: kAmberGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x33F59E0B), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13, color: C.gray900)),
            ),
            Text('+$xp XP',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 14, color: C.gray900)),
          ],
        ),
      ),
    );
  }
}

class OnboardingQuestCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String reward;
  final IconData icon;
  final Color accent;
  final bool locked;

  const OnboardingQuestCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.reward,
    required this.icon,
    required this.accent,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: locked ? C.gray50 : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: locked ? C.gray200 : accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: locked ? C.gray200 : accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: locked ? C.gray400 : accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: locked ? C.gray400 : C.gray900)),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: locked ? C.gray400 : C.gray500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: locked ? C.gray100 : C.amber100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(reward,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: locked ? C.gray400 : C.amber700)),
          ),
        ],
      ),
    );
  }
}
