import 'package:flutter/material.dart';

/// A step's colour identity, shared by roadmap steps and the lists that lead
/// into the roadmap.
class StepAccent {
  final Color color;
  final Color glow;
  final Color badgeBg;
  final Color badgeText;
  final IconData icon;

  const StepAccent({
    required this.color,
    required this.glow,
    required this.badgeBg,
    required this.badgeText,
    required this.icon,
  });
}

abstract final class StepPalette {
  static const List<StepAccent> _accents = [
    StepAccent(
      color: Color(0xFF10B981),
      glow: Color(0xFF059669),
      badgeBg: Color(0xFF064E3B),
      badgeText: Color(0xFF34D399),
      icon: Icons.assignment_turned_in_rounded,
    ),
    StepAccent(
      color: Color(0xFF6366F1),
      glow: Color(0xFF4F46E5),
      badgeBg: Color(0xFF312E81),
      badgeText: Color(0xFFA5B4FC),
      icon: Icons.account_balance_rounded,
    ),
    StepAccent(
      color: Color(0xFF0EA5E9),
      glow: Color(0xFF0284C7),
      badgeBg: Color(0xFF082F49),
      badgeText: Color(0xFF38BDF8),
      icon: Icons.gavel_rounded,
    ),
    StepAccent(
      color: Color(0xFF8B5CF6),
      glow: Color(0xFF7C3AED),
      badgeBg: Color(0xFF2E1065),
      badgeText: Color(0xFFC4B5FD),
      icon: Icons.find_in_page_rounded,
    ),
    StepAccent(
      color: Color(0xFFF59E0B),
      glow: Color(0xFFD97706),
      badgeBg: Color(0xFF451A03),
      badgeText: Color(0xFFFCD34D),
      icon: Icons.auto_stories_rounded,
    ),
  ];

  static const StepAccent fallback = StepAccent(
    color: Color(0xFF38BDF8),
    glow: Color(0xFF0EA5E9),
    badgeBg: Color(0xFF0C4A6E),
    badgeText: Color(0xFF7DD3FC),
    icon: Icons.assignment_rounded,
  );

  static StepAccent of(int stepNumber) =>
      _accents[(stepNumber - 1) % _accents.length];
}
