import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/case_step_entity.dart';
import '../../domain/entities/step_branch.dart';

/// The step screen and the branch screen are both "read a procedure" pages, so
/// they share one visual language. These constants live here so the two cannot
/// drift apart.
class LegalTheme {
  const LegalTheme._();

  static const Color background = Color(0xFFF7F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color hairline = Color(0xFFE5E7EB);

  /// Fallback for a branch with no recognisable outcome.
  static const Color neutral = Color(0xFF4F46E5);

  /// The outcome colour for a branch, derived from its title.
  static Color branchColor(String title) {
    if (title.contains('قبول')) return const Color(0xFF16A34A);
    if (title.contains('رفض')) return const Color(0xFFDC2626);
    if (title.contains('استئناف') || title.contains('طعن')) {
      return const Color(0xFFD97706);
    }
    return neutral;
  }

  /// A very light wash of a colour, for card and step backgrounds.
  static Color tint(Color color) => color.withValues(alpha: 0.07);

  /// The white card used for every section on these pages.
  static BoxDecoration card() => const BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          // Tight and low opacity: lifts the card off the background without
          // the heavy drop shadow of the old design.
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
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
    final hasBranches = step.branches.isNotEmpty;

    // حماية من أي index خارج نطاق الفروع (يمنع RangeError وتوقف الشاشة).
    final safeBranchIndex = _selectedBranchIndex.clamp(
      0,
      step.branches.isEmpty ? 0 : step.branches.length - 1,
    );

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
          title: Text(
            'المرحلة ${step.stepNumber}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: LegalTheme.textPrimary,
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
              _header(),

              // The description comes first and in full: it is the prose the
              // rest of the page explains.
              const SizedBox(height: 18),
              DetailSection(
                title: 'وصف المرحلة',
                icon: Icons.description_outlined,
                accent: LegalTheme.neutral,
                child: Text(
                  step.shortDescription.isNotEmpty
                      ? step.shortDescription
                      : 'تتضمن هذه المرحلة استيفاء الشروط القانونية ومتابعة '
                          'الإجراءات المقررة نظاماً.',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.9,
                    color: LegalTheme.textPrimary,
                  ),
                ),
              ),

              if (hasBranches) ...[
                const SizedBox(height: 18),
                DetailSection(
                  title: 'المسارات والسيناريوهات',
                  icon: Icons.alt_route_rounded,
                  accent: LegalTheme.neutral,
                  trailing: step.branches.length == 1
                      ? 'مسار واحد'
                      : '${step.branches.length} مسارات',
                  child: Column(
                    children: [
                      _BranchSelector(
                        branches: step.branches,
                        selectedIndex: safeBranchIndex,
                        onSelect: (index) =>
                            setState(() => _selectedBranchIndex = index),
                      ),
                      const SizedBox(height: 14),
                      _buildBranchCard(step.branches[safeBranchIndex]),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),
              const DetailSection(
                title: 'نصائح للمحامي',
                icon: Icons.lightbulb_outline_rounded,
                accent: Color(0xFFD97706),
                child: Text(
                  'تأكد من توقيع الموكل على كافة التوكيلات الرسمية والتحقق من '
                  'صحة تواريخ المستندات وسلامتها قبل إيداع الصحيفة أمام قلم الكتاب.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.9,
                    color: LegalTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
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
      for (final station in branch.subSteps) {
        buffer.writeln('- $station');
      }
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ نص المرحلة', textAlign: TextAlign.right),
        backgroundColor: LegalTheme.textPrimary,
      ),
    );
  }

  Widget _buildBranchCard(StepBranch branch) {
    final accent = LegalTheme.branchColor(branch.title);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: LegalTheme.tint(accent),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The outcome is the one fact a reader needs before the detail, so
          // it leads as a solid pill.
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
          if (branch.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              branch.description,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.85,
                color: LegalTheme.textPrimary,
              ),
            ),
          ],
          if (branch.subSteps.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Each step in its own white box so a long procedure can be read
            // one line at a time.
            ...branch.subSteps.map(
              (station) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Text(
                  station,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.7,
                    color: LegalTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2A4A9E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The case name is context, so it stays quiet above the headline.
          Text(
            widget.caseName,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.step.title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // The step number is what a reader checks first when moving
              // through a long case.
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFCA8A04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.step.stepNumber}',
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: LegalTheme.card(),
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
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: LegalTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: accent, size: 21),
            ],
          ),
          // A full-width rule under the heading separates the label from the
          // content, which is what makes each block read as its own unit.
          const Divider(height: 22, thickness: 1, color: LegalTheme.hairline),
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
                color: isSelected ? accent : LegalTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? accent : LegalTheme.hairline,
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
