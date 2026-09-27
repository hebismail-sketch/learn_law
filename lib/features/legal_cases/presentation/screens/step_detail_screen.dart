import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/case_step_entity.dart';
import '../../domain/entities/step_branch.dart';

/// Visual language for the step detail screen.
///
/// Navy carries the legal weight, gold marks what needs attention, and the
/// soft 24px corners keep a long legal page from looking like a wall of boxes.
/// One place to change the palette, so the rest of the app can be brought in
/// line later.
class LegalTheme {
  const LegalTheme._();

  /// Deep navy. Headings, primary surfaces, the app bar.
  static const Color navy = Color(0xFF1E3A8A);
  static const Color navyDark = Color(0xFF152C6B);

  /// Gold. Accents, badges, the step number.
  static const Color gold = Color(0xFFCA8A04);

  /// Surfaces.
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F3F9);

  /// Text.
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  /// Branch outcome colours. Green for accepted, red for rejected, gold for an
  /// appeal, navy for anything unclassified.
  static const Color accepted = Color(0xFF15803D);
  static const Color rejected = Color(0xFFB91C1C);
  static const Color appeal = Color(0xFFCA8A04);
  static const Color neutral = Color(0xFF1E3A8A);

  /// Soft, large corners. The main difference from the previous design.
  static const double radius = 24;
  static const double radiusSmall = 14;

  /// The outcome colour for a branch, derived from its title.
  static Color branchColor(String title) {
    if (title.contains('قبول')) return accepted;
    if (title.contains('رفض')) return rejected;
    if (title.contains('استئناف') || title.contains('طعن')) return appeal;
    return neutral;
  }

  /// A soft tinted fill derived from a branch colour.
  static Color branchTint(Color color) => Color.alphaBlend(
        color.withValues(alpha: 0.08),
        Colors.white,
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
          step.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StepHero(step: step, caseName: widget.caseName),

            const SizedBox(height: 24),

            // The main text gets a label and a marker bar instead of a card,
            // so the page reads top to bottom like a document rather than a
            // stack of boxes.
            _ContentBlock(
              label: 'الإجراءات العامة',
              accent: LegalTheme.navy,
              child: Text(
                step.shortDescription.isNotEmpty
                    ? step.shortDescription
                    : 'تتضمن هذه المرحلة استيفاء الشروط القانونية ومتابعة '
                        'الإجراءات المقررة نظاماً.',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.85,
                  color: LegalTheme.textSecondary,
                ),
              ),
            ),

            if (hasBranches) ...[
              const SizedBox(height: 28),
              _SectionHeading(
                title: 'المسارات والسيناريوهات',
                subtitle: step.branches.length == 1
                    ? 'مسار واحد متاح'
                    : '${step.branches.length} مسارات متاحة',
                accent: LegalTheme.gold,
              ),
              const SizedBox(height: 14),
              _BranchSelector(
                branches: step.branches,
                selectedIndex: safeBranchIndex,
                onSelect: (index) => setState(() => _selectedBranchIndex = index),
              ),
              const SizedBox(height: 16),
              _buildBranchCard(step.branches[safeBranchIndex]),
            ],

            const SizedBox(height: 28),

            _ContentBlock(
              label: 'نصائح للمحامي',
              accent: LegalTheme.gold,
              child: const Text(
                'تأكد من توقيع الموكل على كافة التوكيلات الرسمية والتحقق من '
                'صحة تواريخ المستندات وسلامتها قبل إيداع الصحيفة أمام قلم الكتاب.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.85,
                  color: LegalTheme.textSecondary,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: LegalTheme.branchTint(accent),
        borderRadius: BorderRadius.circular(LegalTheme.radius),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // The outcome is the most useful fact on this card, so it leads: a
          // solid pill carrying the branch name.
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: accent,
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
          Text(
            branch.description.isEmpty
                ? 'لم يتم تحديد تفاصيل لهذا المسار.'
                : branch.description,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              height: 1.85,
              color: LegalTheme.textPrimary,
            ),
          ),
          if (branch.subSteps.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'المحطات المتتالية',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: LegalTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // A dot per station rather than a filled numbered circle: quieter
            // across a long list, and the order is already clear from RTL.
            ...branch.subSteps.map(
              (station) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        station,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: LegalTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The case name and step number, shown as a strong opening block.
class _StepHero extends StatelessWidget {
  final CaseStepEntity step;
  final String caseName;

  const _StepHero({required this.step, required this.caseName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [LegalTheme.navy, LegalTheme.navyDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(LegalTheme.radius),
        boxShadow: [
          BoxShadow(
            color: LegalTheme.navy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // The case name is context rather than the headline, so it reads as
          // a quiet tag above the step title.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              caseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // A gold badge for the number: while reading a long case the step
          // position is the one thing a user looks for first.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  step.title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LegalTheme.gold,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  '${step.stepNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
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

/// A label above content, with no card around it.
class _ContentBlock extends StatelessWidget {
  final String label;
  final Color accent;
  final Widget child;

  const _ContentBlock({
    required this.label,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: LegalTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            // A solid marker bar rather than a circle: it reads as a heading
            // mark, not a button, so it does not look tappable.
            Container(
              width: 6,
              height: 22,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// A heading for a section with more going on, like the branch list.
class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            color: LegalTheme.textMuted,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: LegalTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 6,
          height: 24,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

/// Horizontal branch picker, laid out RTL so the first branch sits on the right.
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
      height: 44,
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
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? accent : LegalTheme.surface,
                borderRadius: BorderRadius.circular(LegalTheme.radiusSmall),
                border: Border.all(
                  color: isSelected ? accent : const Color(0xFFE2E8F0),
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
