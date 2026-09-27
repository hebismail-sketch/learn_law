import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/case_step_entity.dart';
import '../../domain/entities/step_branch.dart';

/// Visual language for the step detail screen.
///
/// Navy carries the legal weight, gold marks what needs attention. Kept in one
/// place so the rest of the app can adopt the same language later.
class LegalTheme {
  const LegalTheme._();

  /// Deep navy. Headings and the hero.
  static const Color navy = Color(0xFF1E3A8A);
  static const Color navyDark = Color(0xFF15266B);

  /// Gold. The step number and accents.
  static const Color gold = Color(0xFFB8860B);

  /// Surfaces.
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color hairline = Color(0xFFE3E8F0);

  /// Text.
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);

  /// Branch outcome colours. Green for accepted, red for rejected, gold for an
  /// appeal, navy for anything unclassified.
  static const Color accepted = Color(0xFF15803D);
  static const Color rejected = Color(0xFFB91C1C);
  static const Color appeal = Color(0xFFB45309);
  static const Color neutral = Color(0xFF1E3A8A);

  /// Corners. Tight enough that a card reads as a block, not a pill.
  static const double radius = 16;
  static const double radiusSmall = 10;

  /// The outcome colour for a branch, derived from its title.
  static Color branchColor(String title) {
    if (title.contains('قبول')) return accepted;
    if (title.contains('رفض')) return rejected;
    if (title.contains('استئناف') || title.contains('طعن')) return appeal;
    return neutral;
  }

  /// A very light wash of a branch colour, for card backgrounds.
  static Color branchTint(Color color) =>
      Color.alphaBlend(color.withValues(alpha: 0.06), Colors.white);
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
    final hasBranches = step.branches.isNotEmpty;

    // حماية من أي index خارج نطاق الفروع (يمنع RangeError وتوقف الشاشة).
    final safeBranchIndex = _selectedBranchIndex.clamp(
      0,
      step.branches.isEmpty ? 0 : step.branches.length - 1,
    );

    return Scaffold(
      backgroundColor: LegalTheme.background,
      appBar: AppBar(
        backgroundColor: LegalTheme.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LegalTheme.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'المرحلة ${step.stepNumber}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: LegalTheme.navy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'نسخ نص المرحلة',
            onPressed: () => _copyStepText(step),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHero(step: step, caseName: widget.caseName),

            // A real gap plus a rule, so the reader can see where one topic
            // ends and the next begins without hunting for it.
            const SizedBox(height: 22),
            const Divider(height: 1, color: LegalTheme.hairline),
            const SizedBox(height: 22),

            _SectionLabel(
              text: 'الإجراءات العامة',
              accent: LegalTheme.navy,
            ),
            const SizedBox(height: 10),
            _Panel(
              child: Text(
                step.shortDescription.isNotEmpty
                    ? step.shortDescription
                    : 'تتضمن هذه المرحلة استيفاء الشروط القانونية ومتابعة '
                        'الإجراءات المقررة نظاماً.',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.9,
                  color: LegalTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            if (hasBranches) ...[
              const SizedBox(height: 22),
              const Divider(height: 1, color: LegalTheme.hairline),
              const SizedBox(height: 22),

              _SectionLabel(
                text: 'المسارات والسيناريوهات',
                accent: LegalTheme.gold,
                trailing: step.branches.length == 1
                    ? 'مسار واحد'
                    : '${step.branches.length} مسارات',
              ),
              const SizedBox(height: 10),
              _BranchSelector(
                branches: step.branches,
                selectedIndex: safeBranchIndex,
                onSelect: (index) => setState(() => _selectedBranchIndex = index),
              ),
              const SizedBox(height: 12),
              _buildBranchCard(step.branches[safeBranchIndex]),
            ],

            const SizedBox(height: 22),
            const Divider(height: 1, color: LegalTheme.hairline),
            const SizedBox(height: 22),

            _SectionLabel(
              text: 'نصائح للمحامي',
              accent: LegalTheme.gold,
            ),
            const SizedBox(height: 10),
            _Panel(
              child: const Text(
                'تأكد من توقيع الموكل على كافة التوكيلات الرسمية والتحقق من '
                'صحة تواريخ المستندات وسلامتها قبل إيداع الصحيفة أمام قلم الكتاب.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.9,
                  color: LegalTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyStepText(CaseStepEntity step) async {
    final buffer = StringBuffer()
      ..writeln('المرحلة ${step.stepNumber}: ${step.title}')
      ..writeln()
      ..writeln(step.shortDescription);
    for (final branch in step.branches) {
      buffer
        ..writeln()
        ..writeln(branch.title)
        ..writeln(branch.description);
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ نص المرحلة',
          textAlign: TextAlign.right,
        ),
        backgroundColor: LegalTheme.navy,
      ),
    );
  }

  Widget _buildBranchCard(StepBranch branch) {
    final accent = LegalTheme.branchColor(branch.title);

    return _Panel(
      tint: LegalTheme.branchTint(accent),
      borderColor: accent.withValues(alpha: 0.22),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A bar plus the name: the outcome is the one fact a reader needs
          // before the detail below it.
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  branch.title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            branch.description.isEmpty
                ? 'لم يتم تحديد تفاصيل لهذا المسار.'
                : branch.description,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              height: 1.9,
              color: LegalTheme.textPrimary,
            ),
          ),

          if (branch.subSteps.isNotEmpty) ...[
            const SizedBox(height: 18),
            // A rule inside the card separates the prose from the ordered
            // stations, which are a different kind of content.
            Divider(height: 1, color: accent.withValues(alpha: 0.18)),
            const SizedBox(height: 14),
            const Text(
              'المحطات المتتالية',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: LegalTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            // Numbered, because a reader following a procedure needs to know
            // which station comes first, second and third.
            ...branch.subSteps.asMap().entries.map(
                  (entry) => _StationRow(
                    number: entry.key + 1,
                    text: entry.value,
                    accent: accent,
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// One numbered station inside a branch.
class _StationRow extends StatelessWidget {
  final int number;
  final String text;
  final Color accent;

  const _StationRow({
    required this.number,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The number sits on the right in this RTL layout, which is where
          // the eye starts.
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.75,
                  color: LegalTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section title with a coloured marker and an optional count on the left.
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color accent;
  final String? trailing;

  const _SectionLabel({
    required this.text,
    required this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (trailing != null) ...[
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12.5,
              color: LegalTheme.textMuted,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: LegalTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

/// A white block. One box style, so every section on the page matches.
class _Panel extends StatelessWidget {
  final Widget child;
  final Color tint;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  const _Panel({
    required this.child,
    this.tint = LegalTheme.surface,
    this.borderColor = LegalTheme.hairline,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(LegalTheme.radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// The case name and step title, shown as a strong opening block.
class _StepHero extends StatelessWidget {
  final CaseStepEntity step;
  final String caseName;

  const _StepHero({required this.step, required this.caseName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: LegalTheme.navy,
        borderRadius: BorderRadius.circular(LegalTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            caseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  step.title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // The step number is what a reader checks first when moving
              // through a long case, so it gets the only accent on the page.
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LegalTheme.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${step.stepNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
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
                color: isSelected ? accent : LegalTheme.surface,
                borderRadius: BorderRadius.circular(LegalTheme.radiusSmall),
                border: Border.all(
                  color: isSelected ? accent : LegalTheme.hairline,
                ),
              ),
              child: Text(
                branch.title,
                style: TextStyle(
                  color: isSelected ? Colors.white : LegalTheme.textSecondary,
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
