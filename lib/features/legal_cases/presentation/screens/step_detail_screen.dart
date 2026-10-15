import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../domain/entities/case_step_entity.dart';
import '../../domain/entities/step_branch.dart';
import '../widgets/step_palette.dart';

/// Dark design tokens shared by the step and branch detail pages.
class LegalTheme {
  const LegalTheme._();

  static Color get background => AppColors.background;
  static Color get surface => AppColors.surface;
  static Color get surfaceRaised => AppColors.raisedSurface;
  static Color get hairline => AppColors.border;
  static Color get textPrimary => AppColors.textPrimary;
  static Color get textSecondary => AppColors.textSecondary;
  static Color get textMuted => AppColors.textMuted;

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

    return rebuildWithAppTheme(
      (context) => Directionality(
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
            title: Text(
              'تفاصيل المرحلة',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: LegalTheme.textPrimary,
              ),
            ),
            actions: const [ThemeToggleButton()],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(accent),
                    const SizedBox(height: 13),
                    _stepsCard(
                      step: step,
                      items: items,
                      selectedIndex: safeBranchIndex,
                      accent: accent,
                      onBranchSelected: hasBranches && step.branches.length > 1
                          ? (index) =>
                                setState(() => _selectedBranchIndex = index)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: _stepNavigation(accent),
        ),
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
          top: BorderSide(color: accent.color.withValues(alpha: 0.22)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppThemeController.isLight.value ? 0.04 : 0.16,
            ),
            blurRadius: 16,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: hasPrevious
                      ? () => _showStep(_currentStepIndex - 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('السابقة'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  '${_currentStepIndex + 1} من ${widget.steps.length}',
                  style: TextStyle(
                    color: LegalTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: hasNext
                      ? () => _showStep(_currentStepIndex + 1)
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('التالية'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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
    final progress = (_currentStepIndex + 1) / widget.steps.length;
    final isLight = AppThemeController.isLight.value;

    return Container(
      key: const ValueKey('step-detail-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: LegalTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.color.withValues(alpha: isLight ? 0.22 : 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.035 : 0.13),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.color.withValues(alpha: isLight ? 0.10 : 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(accent.icon, color: accent.color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'المرحلة ${step.stepNumber}',
                      style: TextStyle(
                        color: isLight ? accent.glow : accent.color,
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step.title,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: LegalTheme.textPrimary,
                        fontSize: 14.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.raisedSurface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: LegalTheme.hairline),
                ),
                child: Text(
                  '${_currentStepIndex + 1} / ${widget.steps.length}',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: accent.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (widget.steps.length > 1) ...[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: accent.color.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation<Color>(accent.color),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: LegalTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: LegalTheme.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإجراءات القانونية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: LegalTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.color.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: accent.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                key: const ValueKey('steps-heading-icon'),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: accent.color.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(Icons.forum_rounded, color: accent.color, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                style: TextStyle(
                  color: AppThemeController.isLight.value
                      ? LegalTheme.textPrimary
                      : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (items.isEmpty)
          Text(
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
    final isLight = AppThemeController.isLight.value;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: onRight ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.92,
            child: Container(
              key: ValueKey('step-tile-$index'),
              margin: const EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.fromLTRB(
                onRight ? 14 : 31,
                14,
                onRight ? 31 : 14,
                15,
              ),
              decoration: BoxDecoration(
                color: LegalTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(onRight ? 22 : 8),
                  bottomRight: Radius.circular(onRight ? 8 : 22),
                ),
                border: Border.all(color: LegalTheme.hairline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isLight ? 0.045 : 0.14,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'الإجراء $number',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isLight
                                ? accent
                                : accent.withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      fontWeight: FontWeight.w600,
                      color: LegalTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: onRight ? -13 : null,
          left: onRight ? null : -13,
          child: Container(
            key: ValueKey('step-number-$index'),
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              border: Border.all(color: LegalTheme.surface, width: 3),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isLight ? 0.2 : 0.32),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
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
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: LegalTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: LegalTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: accent, size: 22),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
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

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(index),
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? accent : LegalTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? accent : accent.withValues(alpha: 0.3),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.24),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      branch.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : LegalTheme.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
