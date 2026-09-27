import 'package:flutter/material.dart';

import '../../domain/entities/step_branch.dart';

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
  Color get _accentColor {
    if (branch.outcome == 'acceptance' || branch.title.contains('قبول')) {
      return const Color(0xFF16A34A);
    }
    if (branch.outcome == 'rejection' || branch.title.contains('رفض')) {
      return const Color(0xFFDC2626);
    }
    if (branch.outcome == 'appeal' ||
        branch.title.contains('استئناف') ||
        branch.title.contains('طعن')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF4F46E5);
  }

  /// A very light wash of the accent, for the individual step boxes.
  Color get _stepTint => _accentColor.withValues(alpha: 0.07);

  @override
  Widget build(BuildContext context) {
    final hasContent = branch.description.trim().isNotEmpty ||
        branch.subSteps.isNotEmpty ||
        branch.branches.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F7FB),
          surfaceTintColor: Colors.transparent,
          foregroundColor: const Color(0xFF1F2937),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: const Text(
            'تفاصيل المسار',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 18),

              if (branch.description.trim().isNotEmpty) ...[
                _section(
                  title: 'وصف المسار',
                  icon: Icons.description_outlined,
                  child: Text(
                    branch.description,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.9,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              if (branch.subSteps.isNotEmpty) ...[
                _section(
                  title: 'خصائص وإجراءات المسار',
                  icon: Icons.list_alt_rounded,
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
                              color: _stepTint,
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
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              if (branch.branches.isNotEmpty) ...[
                _section(
                  title: 'مسارات فرعية',
                  icon: Icons.alt_route_rounded,
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
                                color: Color(0xFF1F2937),
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
                const SizedBox(height: 18),
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

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          // A tight, low-opacity shadow: enough to lift the card off the
          // background without the heavy drop shadow of the old design.
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: _accentColor, size: 21),
            ],
          ),
          // A full-width rule under the heading separates the label from the
          // content, which is what makes each block read as its own unit.
          const Divider(height: 22, thickness: 1, color: Color(0xFFE5E7EB)),
          child,
        ],
      ),
    );
  }
}
