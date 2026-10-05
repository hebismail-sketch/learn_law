import 'package:flutter/material.dart';

import '../../domain/entities/case_step_entity.dart';
import '../../domain/entities/step_branch.dart';

/// A single step's colour identity: the circle colour in the roadmap, and the
/// accent used everywhere the step is opened.
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

/// The one place that decides a step's colour, shared by the roadmap and the
/// detail screen so a step keeps the same identity wherever it appears.
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

  /// The accent of a step, derived from its number so it never changes between
  /// the roadmap node and the screen it opens.
  static StepAccent of(int stepNumber) =>
      _accents[(stepNumber - 1) % _accents.length];
}

/// Dark design tokens shared by the step and branch detail pages.
class LegalTheme {
  const LegalTheme._();

  static const Color background = Color(0xFF0B101D);
  static const Color surface = Color(0xFF161F36);
  static const Color surfaceRaised = Color(0xFF1E293B);
  static const Color hairline = Color(0xFF3B4C7A);
  // النصوص الأساسية بياض خالص عشان تبقى واضحة على الخلفية الداكنة.
  static const Color textPrimary = Color(0xFFFFFFFF);
  // النص التانوي (الأوصاف) رمادي فاتح مش باهت.
  static const Color textSecondary = Color(0xFFCBD5E1);
  // العدادات واللمسات الثانوية: رمادي متوسط الوضوح.
  static const Color textMuted = Color(0xFF94A3B8);

  /// Outcome colours for a branch: accepting, rejecting, escalating.
  static Color branchColor(String title) {
    if (title.contains('قبول')) return const Color(0xFF10B981);
    if (title.contains('رفض')) return const Color(0xFFEF4444);
    if (title.contains('استئناف') || title.contains('طعن')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF38BDF8);
  }

  /// A dark-tinted surface that still reads as "tinted" under a strong accent.
  static Color tint(Color color) =>
      Color.alphaBlend(color.withValues(alpha: 0.14), surface);

  static BoxDecoration card(Color accent) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: accent.withValues(alpha: 0.32)),
    boxShadow: [
      BoxShadow(
        color: accent.withValues(alpha: 0.16),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

class StepDetailScreen extends StatefulWidget {
  final String caseName;
  final CaseStepEntity step;

  const StepDetailScreen({
    super.key,
    required this.caseName,
    required this.step,
  });

  @override
  State<StepDetailScreen> createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen> {
  int _selectedBranchIndex = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final accent = StepPalette.of(step.stepNumber);
    final hasBranches = step.branches.isNotEmpty;
    final safeBranchIndex = _selectedBranchIndex.clamp(
      0,
      hasBranches ? step.branches.length - 1 : 0,
    );

    // The bullets under "خصائص وإجراءات المسار": the ones of the selected
    // branch, or a list derived from the step prose when it has no branching.
    final items = hasBranches
        ? step.branches[safeBranchIndex].subSteps
        : _stepsFromProse(step);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: LegalTheme.background,
        appBar: AppBar(
          backgroundColor: LegalTheme.background,
          surfaceTintColor: Colors.transparent,
          foregroundColor: LegalTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: const Text(
            'تفاصيل المسار',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: LegalTheme.textPrimary,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(accent),
              const SizedBox(height: 20),
              // 1) الوصف first, 2) the steps underneath, always in that order.
              _descriptionCard(step, accent),
              const SizedBox(height: 20),
              _stepsCard(
                step: step,
                items: items,
                selectedIndex: safeBranchIndex,
                accent: accent,
                onBranchSelected: hasBranches && step.branches.length > 1
                    ? (index) => setState(() => _selectedBranchIndex = index)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// When a step has no branches at all we still need bullets, so we split its
  /// own description into sentences.
  List<String> _stepsFromProse(CaseStepEntity step) {
    if (step.branches.isNotEmpty) return const [];
    return step.shortDescription
        .split(RegExp(r'[.،\n]'))
        .map((e) => e.trim())
        .where((e) => e.length > 10)
        .toList();
  }

  Widget _header(StepAccent accent) {
    final step = widget.step;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.glow, accent.color],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.glow.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The badge mirrors the roadmap pill: same colour, same wording.
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'المرحلة (${step.stepNumber})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  step.title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.45,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // The circle from the roadmap, kept so the page is recognisable.
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: Icon(accent.icon, color: Colors.white, size: 24),
              ),
            ],
          ),
          if (step.shortDescription.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.caseName,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _descriptionCard(CaseStepEntity step, StepAccent accent) {
    return DetailSection(
      title: 'وصف المسار',
      icon: Icons.description_outlined,
      accent: accent.color,
      child: Text(
        step.shortDescription.isNotEmpty
            ? step.shortDescription
            : 'تتضمن هذه المرحلة استيفاء الشروط القانونية ومتابعة '
                  'الإجراءات المقررة نظاماً.',
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 15.5,
          height: 1.9,
          fontWeight: FontWeight.w500,
          color: LegalTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _stepsCard({
    required CaseStepEntity step,
    required List<String> items,
    required int selectedIndex,
    required StepAccent accent,
    void Function(int index)? onBranchSelected,
  }) {
    final hasBranches = step.branches.isNotEmpty;
    final branch = hasBranches ? step.branches[selectedIndex] : null;
    final label = items.isEmpty
        ? 'لا توجد خطوات'
        : items.length == 1
        ? 'خطوة واحدة'
        : items.length == 2
        ? 'خطوتان'
        : items.length <= 10
        ? '${items.length} خطوات'
        : '+10 خطوات';

    return DetailSection(
      title: 'خصائص وإجراءات المسار',
      icon: Icons.list_alt_rounded,
      accent: accent.color,
      trailing: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBranchSelected != null) ...[
            _BranchSelector(
              branches: step.branches,
              selectedIndex: selectedIndex,
              onSelect: onBranchSelected,
            ),
            const SizedBox(height: 16),
          ] else if (branch != null && branch.title.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: LegalTheme.branchColor(branch.title),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  branch.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (items.isEmpty)
            const Text(
              'لا توجد خطوات مسجلة لهذه المرحلة.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.8,
                color: LegalTheme.textMuted,
              ),
            )
          else
            // Every step in its own raised dark card with a leading index
            // marker, so a long procedure is scannable line by line.
            ...items.asMap().entries.map(
              (entry) => _StepTile(
                index: entry.key + 1,
                text: entry.value,
                accent: accent.color,
              ),
            ),
        ],
      ),
    );
  }
}

/// One step of the procedure: an index marker, the text, and a hairline that
/// ties the whole list into a single procedure.
class _StepTile extends StatelessWidget {
  final int index;
  final String text;
  final Color accent;

  const _StepTile({
    required this.index,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: LegalTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                height: 1.85,
                fontWeight: FontWeight.w600,
                color: LegalTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The white card used for every section: a coloured icon, a title, a rule,
/// then the content. Public so the branch screen reuses it and the two pages
/// cannot drift apart.
class DetailSection extends StatelessWidget {
  final String title;
  final String? trailing;
  final IconData icon;
  final Color accent;
  final Widget child;

  const DetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: LegalTheme.card(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: LegalTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: LegalTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: accent, size: 22),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Divider(height: 1, thickness: 1, color: LegalTheme.hairline),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Branch picker, laid out RTL so the first branch sits on the right.
class _BranchSelector extends StatelessWidget {
  final List<StepBranch> branches;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _BranchSelector({
    required this.branches,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // reverse: true places index 0 on the right in an RTL context.
        reverse: true,
        itemCount: branches.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final branch = branches[index];
          final accent = LegalTheme.branchColor(branch.title);
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? accent : LegalTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? accent : accent.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                branch.title,
                style: TextStyle(
                  color: isSelected ? Colors.white : LegalTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
