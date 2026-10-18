import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
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
              'تفاصيل المسار',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: LegalTheme.textPrimary,
              ),
            ),
            actions: const [ThemeToggleButton()],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 13),
                _sectionHeader(
                  title: 'الإجراءات القانونية',
                  icon: Icons.forum_rounded,
                  count: branch.subSteps.length,
                  key: const ValueKey('branch-procedures-heading'),
                ),
                const SizedBox(height: 16),
                if (branch.subSteps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'لا توجد خطوات مسجلة لهذا المسار.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.8,
                        color: LegalTheme.textMuted,
                      ),
                    ),
                  )
                else
                  ...branch.subSteps.asMap().entries.map(
                    (entry) => _BranchProcedureTile(
                      index: entry.key + 1,
                      text: entry.value,
                      accent: _accentColor,
                    ),
                  ),

                if (branch.branches.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _sectionHeader(
                    title: 'مسارات فرعية',
                    icon: Icons.alt_route_rounded,
                    count: branch.branches.length,
                    countLabel: 'مسار',
                    key: const ValueKey('nested-branches-heading'),
                  ),
                  const SizedBox(height: 12),
                  ...branch.branches.asMap().entries.map((entry) {
                    final child = entry.value;
                    final childAccent = _branchAccent(child);
                    return Container(
                      key: ValueKey('child-branch-${entry.key}'),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: LegalTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: childAccent.withValues(alpha: 0.24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: AppThemeController.isLight.value
                                  ? 0.035
                                  : 0.12,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => BranchDetailScreen(
                                caseName: caseName,
                                branch: child,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.chevron_left_rounded,
                                  color: childAccent,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    child.title,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: LegalTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: childAccent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    Icons.alt_route_rounded,
                                    color: childAccent,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final isLight = AppThemeController.isLight.value;
    return Container(
      key: const ValueKey('branch-detail-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: LegalTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _accentColor.withValues(alpha: isLight ? 0.22 : 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.035 : 0.13),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: isLight ? 0.10 : 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_outcomeIcon, color: _accentColor, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _outcomeLabel,
                  style: TextStyle(
                    color: isLight ? _accentColor : _accentColor,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  branch.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.raisedSurface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: LegalTheme.hairline),
            ),
            child: Icon(_outcomeIcon, color: _accentColor, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required int count,
    required Key key,
    String countLabel = 'خطوة',
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LegalTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LegalTheme.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: LegalTheme.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              '$count $countLabel',
              style: TextStyle(
                color: _accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _accentColor.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: _accentColor, size: 20),
          ),
        ],
      ),
    );
  }

  String get _outcomeLabel => switch (branch.outcome) {
    'acceptance' => 'مسار قبول',
    'rejection' => 'مسار رفض',
    'appeal' => 'مسار استئناف',
    _ => 'مسار قانوني',
  };

  IconData get _outcomeIcon => switch (branch.outcome) {
    'acceptance' => Icons.check_rounded,
    'rejection' => Icons.close_rounded,
    'appeal' => Icons.gavel_rounded,
    _ => Icons.alt_route_rounded,
  };

  Color _branchAccent(StepBranch item) {
    switch (item.outcome) {
      case 'acceptance':
        return const Color(0xFF16A34A);
      case 'rejection':
        return const Color(0xFFDC2626);
      case 'appeal':
        return const Color(0xFFD97706);
    }
    return LegalTheme.branchColor(item.title);
  }
}

class _BranchProcedureTile extends StatelessWidget {
  final int index;
  final String text;
  final Color accent;

  const _BranchProcedureTile({
    required this.index,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final onRight = index.isOdd;
    final isLight = AppThemeController.isLight.value;
    final number = index.toString().padLeft(2, '0');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: onRight ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.92,
            child: Container(
              key: ValueKey('branch-procedure-$index'),
              margin: const EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.fromLTRB(
                onRight ? 14 : 31,
                13,
                onRight ? 31 : 14,
                14,
              ),
              decoration: BoxDecoration(
                color: LegalTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(21),
                  topRight: const Radius.circular(21),
                  bottomLeft: Radius.circular(onRight ? 21 : 8),
                  bottomRight: Radius.circular(onRight ? 8 : 21),
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
                  Text(
                    'الإجراء $number',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    text,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
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
          top: 9,
          right: onRight ? -13 : null,
          left: onRight ? null : -13,
          child: Container(
            key: ValueKey('branch-procedure-number-$index'),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              border: Border.all(color: LegalTheme.surface, width: 3),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isLight ? 0.20 : 0.32),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
