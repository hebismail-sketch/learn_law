import 'package:flutter/material.dart';

import '../../domain/entities/step_branch.dart';
import 'step_detail_screen.dart';

class BranchDetailScreen extends StatelessWidget {
  final String caseName;
  final StepBranch branch;

  const BranchDetailScreen({
    super.key,
    required this.caseName,
    required this.branch,
  });

  /// The branch's own colour, used for the header and every accent on the page
  /// so the outcome stays obvious at a glance.
  ///
  /// The stored `outcome` is preferred over matching on the title, because a
  /// title can be renamed by an admin while the outcome stays the same.
  Color get _accentColor {
    switch (branch.outcome) {
      case 'acceptance':
        return const Color(0xFF16A34A);
      case 'rejection':
        return const Color(0xFFDC2626);
      case 'appeal':
        return const Color(0xFFD97706);
    }
    // Fall back to the title for branches written before `outcome` was stored.
    return LegalTheme.branchColor(branch.title);
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = branch.description.trim().isNotEmpty ||
        branch.subSteps.isNotEmpty ||
        branch.branches.isNotEmpty;

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),

              // The description comes first and in full, matching the order on
              // the step screen.
              if (branch.description.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                DetailSection(
                  title: 'وصف المسار',
                  icon: Icons.description_outlined,
                  accent: _accentColor,
                  child: Text(
                    branch.description,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.9,
                      color: LegalTheme.textPrimary,
                    ),
                  ),
                ),
              ],

              if (branch.subSteps.isNotEmpty) ...[
                const SizedBox(height: 18),
                DetailSection(
                  title: 'خصائص وإجراءات المسار',
                  icon: Icons.list_alt_rounded,
                  accent: _accentColor,
                  trailing: '${branch.subSteps.length} خطوة',
                  // Each step gets its own tinted box, so a long procedure can
                  // be scanned one line at a time instead of as a wall of text.
                  child: Column(
                    children: branch.subSteps
                        .map(
                          (step) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: LegalTheme.tint(_accentColor),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _accentColor.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              step,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.7,
                                color: LegalTheme.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],

              if (branch.branches.isNotEmpty) ...[
                const SizedBox(height: 18),
                DetailSection(
                  title: 'مسارات فرعية',
                  icon: Icons.alt_route_rounded,
                  accent: _accentColor,
                  trailing: '${branch.branches.length} مسارات',
                  child: Column(
                    children: branch.branches
                        .map(
                          (child) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: _accentColor,
                              size: 16,
                            ),
                            title: Text(
                              child.title,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: LegalTheme.textPrimary,
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BranchDetailScreen(
                                  caseName: caseName,
                                  branch: child,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],

              if (!hasContent)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'لم تتم إضافة تفاصيل لهذا المسار بعد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        // A soft diagonal gradient rather than a flat fill, so the header reads
        // as the top of the page instead of another white card.
        gradient: LinearGradient(
          colors: [_accentColor, _accentColor.withValues(alpha: 0.78)],
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
            caseName,
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
          Text(
            branch.title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
