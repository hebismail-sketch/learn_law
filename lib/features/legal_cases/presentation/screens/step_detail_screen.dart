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
  final List<CaseStepEntity> steps;
  final int initialStepIndex;

  StepDetailScreen({
    super.key,
    required this.caseName,
    required this.steps,
    required this.initialStepIndex,
  }) : assert(steps.isNotEmpty),
       assert(initialStepIndex >= 0 && initialStepIndex < steps.length);

  @override
  State<StepDetailScreen> createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen> {
  late int _currentStepIndex;
  int _selectedBranchIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentStepIndex = widget.initialStepIndex;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStepIndex];
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
        bottomNavigationBar: _stepNavigation(accent),
      ),
    );
  }

  void _showStep(int index) {
    setState(() {
      _currentStepIndex = index;
      _selectedBranchIndex = 0;
    });
  }

  Widget _stepNavigation(StepAccent accent) {
    if (widget.steps.length < 2) return const SizedBox.shrink();

    final hasPrevious = _currentStepIndex > 0;
    final hasNext = _currentStepIndex < widget.steps.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: LegalTheme.surface,
        border: Border(
          top: BorderSide(color: accent.color.withValues(alpha: 0.35)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: hasPrevious
                      ? () => _showStep(_currentStepIndex - 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('السابقة'),
                ),
              ),
              Text(
                '${_currentStepIndex + 1} من ${widget.steps.length}',
                style: const TextStyle(
                  color: LegalTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: hasNext
                      ? () => _showStep(_currentStepIndex + 1)
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('التالية'),
                ),
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
        .split(RegExp(r'(?<=[.!؟۔?])|\n+'))
        .map((e) => e.trim())
        .where((e) => e.length > 10)
        .toList();
  }

  Widget _header(StepAccent accent) {
    final step = widget.steps[_currentStepIndex];
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'المرحلة (${step.stepNumber})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.color.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: accent.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Container(
                key: const ValueKey('steps-heading-icon'),
                width: 40,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.color.withValues(alpha: 0.34),
                  ),
                ),
                child: Icon(Icons.forum_rounded, color: accent.color, size: 19),
              ),
              const SizedBox(width: 8),
              const Text(
                'خصائص وإجراءات المسار',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: LegalTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: LegalTheme.branchColor(branch.title),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: LegalTheme.branchColor(
                      branch.title,
                    ).withValues(alpha: 0.24),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
          ...items.asMap().entries.map(
            (entry) => _StepTile(
              index: entry.key + 1,
              text: entry.value,
              accent: accent.color,
            ),
          ),
      ],
    );
  }
}

/// A numbered chat-style bubble that alternates sides down the procedure.
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
    final onRight = index.isOdd;
    final number = index.toString().padLeft(2, '0');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: onRight ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.88,
            child: Container(
              key: ValueKey('step-tile-$index'),
              margin: const EdgeInsets.only(bottom: 20),
              padding: EdgeInsets.fromLTRB(
                onRight ? 15 : 38,
                16,
                onRight ? 38 : 15,
                18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: onRight
                      ? [
                          Color.alphaBlend(
                            accent.withValues(alpha: 0.13),
                            LegalTheme.surfaceRaised,
                          ),
                          LegalTheme.surface,
                        ]
                      : [LegalTheme.surfaceRaised, LegalTheme.surface],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(25),
                  topRight: const Radius.circular(25),
                  bottomLeft: Radius.circular(onRight ? 25 : 9),
                  bottomRight: Radius.circular(onRight ? 9 : 25),
                ),
                border: Border.all(color: accent.withValues(alpha: 0.38)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: onRight ? 0.22 : 0.15),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: Offset(onRight ? -3 : 3, 11),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'الخطوة $number',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 16.5,
                      height: 1.8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Color(0x3387CEFA), blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: onRight ? -18 : null,
          left: onRight ? null : -18,
          child: Container(
            key: ValueKey('step-number-$index'),
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: 0.18),
                    accent,
                  ),
                ],
              ),
              border: Border.all(color: LegalTheme.background, width: 3),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.48),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
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
