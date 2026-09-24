import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/legal_case_entity.dart';
import '../../domain/entities/case_step_entity.dart';
import '../../domain/entities/step_branch.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import 'step_detail_screen.dart';
import 'branch_detail_screen.dart';

class CaseRoadmapScreen extends StatelessWidget {
  final LegalCaseEntity legalCase;

  const CaseRoadmapScreen({
    super.key,
    required this.legalCase,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: AppBar(
        title: Text(
          legalCase.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF0B101D),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _GridBackgroundPattern(),
          ),
          BlocBuilder<LegalCubit, LegalState>(
            builder: (context, state) {
              if (state is LegalLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF38BDF8),
                  ),
                );
              }

              if (state is CaseStepsLoaded) {
                final steps = state.caseSteps;

                if (steps.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.route_outlined,
                          size: 64,
                          color: Colors.blueGrey.shade700,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لم يتم إضافة خطوات ومسارات بعد',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      _buildHeaderBadge(steps.length),
                      const SizedBox(height: 32),
                      _RoadmapGraph(
                        caseName: legalCase.name,
                        caseId: legalCase.id,
                        steps: steps,
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                );
              }

              if (state is LegalError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'حدث خطأ: ${state.message}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF161F36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E3D66),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF38BDF8).withOpacity(0.4),
              ),
            ),
            child: Text(
              '$count محطات ومسارات',
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    legalCase.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.hub_rounded,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BACKGROUND
// ============================================================================

class _GridBackgroundPattern extends StatelessWidget {
  const _GridBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGridPainter(),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A3655).withOpacity(0.4)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    const spacing = 28.0;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(
          Offset(x, y),
          1.2,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ============================================================================
// ROADMAP GRAPH
// ============================================================================

class _RoadmapGraph extends StatelessWidget {
  final String caseName;
  final String caseId;
  final List<CaseStepEntity> steps;

  const _RoadmapGraph({
    required this.caseName,
    required this.caseId,
    required this.steps,
  });

  void _openStep(
      BuildContext context,
      CaseStepEntity step,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StepDetailScreen(
          caseName: caseName,
          step: step,
        ),
      ),
    );
  }

  void _openBranch(
      BuildContext context,
      StepBranch branch,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchDetailScreen(
          caseName: caseName,
          branch: branch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int index = 0; index < steps.length; index++) ...[
          _MainStepNode(
            step: steps[index],
            onTap: () => _openStep(
              context,
              steps[index],
            ),
          ),

          // فروع الخطوة تظهر مباشرة تحتها (وليس بينها وبين الخطوة التالية)
          // حتى تظهر فروع آخر خطوة أيضاً.
          _StepConnection(
            step: steps[index],
            onBranchTap: (branch) => _openBranch(context, branch),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// MAIN STEP
// ============================================================================

class _MainStepNode extends StatelessWidget {
  final CaseStepEntity step;
  final VoidCallback onTap;

  const _MainStepNode({
    required this.step,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = step.stepNumber == 1;

    final themes = [
      {
        'color': const Color(0xFF10B981),
        'glow': const Color(0xFF059669),
        'badgeBg': const Color(0xFF064E3B),
        'badgeText': const Color(0xFF34D399),
        'icon': Icons.assignment_turned_in_rounded,
      },
      {
        'color': const Color(0xFF6366F1),
        'glow': const Color(0xFF4F46E5),
        'badgeBg': const Color(0xFF312E81),
        'badgeText': const Color(0xFFA5B4FC),
        'icon': Icons.account_balance_rounded,
      },
      {
        'color': const Color(0xFF0EA5E9),
        'glow': const Color(0xFF0284C7),
        'badgeBg': const Color(0xFF082F49),
        'badgeText': const Color(0xFF38BDF8),
        'icon': Icons.gavel_rounded,
      },
      {
        'color': const Color(0xFF8B5CF6),
        'glow': const Color(0xFF7C3AED),
        'badgeBg': const Color(0xFF2E1065),
        'badgeText': const Color(0xFFC4B5FD),
        'icon': Icons.find_in_page_rounded,
      },
      {
        'color': const Color(0xFFF59E0B),
        'glow': const Color(0xFFD97706),
        'badgeBg': const Color(0xFF451A03),
        'badgeText': const Color(0xFFFCD34D),
        'icon': Icons.auto_stories_rounded,
      },
    ];

    final theme = themes[(step.stepNumber - 1) % themes.length];

    final Color nodeColor = isFirst
        ? const Color(0xFF10B981)
        : theme['color'] as Color;

    final Color glowColor = isFirst
        ? const Color(0xFF059669)
        : theme['glow'] as Color;

    final Color badgeBg = isFirst
        ? const Color(0xFF064E3B)
        : theme['badgeBg'] as Color;

    final Color badgeTextColor = isFirst
        ? const Color(0xFF34D399)
        : theme['badgeText'] as Color;

    final IconData iconData = theme['icon'] as IconData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 380,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: nodeColor,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.45),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: nodeColor.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 2.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    iconData,
                    color: Colors.white,
                    size: 30,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${step.stepNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isFirst
                    ? '✓ تم البدء والإعداد'
                    : 'المرحلة (${step.stepNumber})',
                style: TextStyle(
                  color: badgeTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            if (step.shortDescription.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                step.shortDescription,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CONNECTION BETWEEN MAIN STEPS
// ============================================================================

class _StepConnection extends StatelessWidget {
  final CaseStepEntity step;
  final void Function(StepBranch branch) onBranchTap;

  const _StepConnection({
    required this.step,
    required this.onBranchTap,
  });

  @override
  Widget build(BuildContext context) {
    final branches = step.branches
        .where(
          (branch) =>
      branch.title.trim().isNotEmpty ||
          branch.subSteps.any(
                (item) => item.trim().isNotEmpty,
          ) ||
          branch.branches.isNotEmpty,
    )
        .toList();

    if (branches.isEmpty) {
      return const SizedBox(
        height: 58,
        width: 20,
        child: CustomPaint(
          painter: _DashedVerticalPainter(
            color: Color(0xFF38BDF8),
          ),
        ),
      );
    }

    return _BranchSection(
      branches: branches,
      onBranchTap: onBranchTap,
      isNested: false,
    );
  }
}

// ============================================================================
// BRANCH SECTION
// ============================================================================

class _BranchSection extends StatelessWidget {
  final List<StepBranch> branches;
  final void Function(StepBranch branch) onBranchTap;
  final bool isNested;

  const _BranchSection({
    required this.branches,
    required this.onBranchTap,
    required this.isNested,
  });

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;

        final rawLaneWidth =
            (constraints.maxWidth -
                (gap * (branches.length - 1))) /
                branches.length;

        final laneWidth = math.max<double>(
          145.0,
          math.min<double>(rawLaneWidth, 210.0),
        );

        final totalWidth =
            laneWidth * branches.length +
                gap * (branches.length - 1);

        final content = SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              _BranchForkConnector(
                branchCount: branches.length,
                laneWidth: laneWidth,
                gap: gap,
                color: isNested
                    ? const Color(0xFF818CF8)
                    : const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int index = 0;
                  index < branches.length;
                  index++) ...[
                    if (index > 0)
                      const SizedBox(width: gap),
                    SizedBox(
                      width: laneWidth,
                      child: _BranchLane(
                        branch: branches[index],
                        branchNumber: index + 1,
                        onBranchTap: onBranchTap,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _BranchMergeConnector(
                branchCount: branches.length,
                laneWidth: laneWidth,
                gap: gap,
                color: isNested
                    ? const Color(0xFF818CF8)
                    : const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 12),
              const SizedBox(
                height: 48,
                width: 20,
                child: CustomPaint(
                  painter: _DashedArrowPainter(
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
        );

        if (totalWidth <= constraints.maxWidth) {
          return Center(
            child: content,
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: content,
        );
      },
    );
  }
}

// ============================================================================
// BRANCH LANE
// ============================================================================

class _BranchLane extends StatelessWidget {
  final StepBranch branch;
  final int branchNumber;
  final void Function(StepBranch branch) onBranchTap;

  const _BranchLane({
    required this.branch,
    required this.branchNumber,
    required this.onBranchTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubSteps = branch.subSteps.any(
      (step) => step.trim().isNotEmpty,
    );

    final nestedBranches = branch.branches
        .where(
          (child) =>
      child.title.trim().isNotEmpty ||
          child.subSteps.any(
                (item) => item.trim().isNotEmpty,
          ) ||
          child.branches.isNotEmpty,
    )
        .toList();

    final Color accentColor = branchNumber == 1
        ? const Color(0xFF10B981)
        : const Color(0xFF818CF8);

    return Column(
      children: [
        if (branch.title.trim().isNotEmpty)
          _BranchTitle(
            title: branch.title,
            accentColor: accentColor,
            branchNumber: branchNumber,
            hasSubSteps: hasSubSteps,
            onTap: () => onBranchTap(branch),
          ),

        // NOTE: لا نقسم خصائص الفرع إلى عقد منفصلة — الضغط على اسم الفرع
        // يفتح صفحة واحدة تحتوي كل محتواه (الوصف + المحطات + الفروع الفرعية).

        if (nestedBranches.isNotEmpty) ...[
          const SizedBox(height: 12),

          _BranchSection(
            branches: nestedBranches,
            onBranchTap: onBranchTap,
            isNested: true,
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// BRANCH TITLE
// ============================================================================

class _BranchTitle extends StatelessWidget {
  final String title;
  final Color accentColor;
  final int branchNumber;
  final VoidCallback onTap;

  /// هل يحتوي هذا الفرع على محتوى (محطات/خصائص)؟ تُستخدم لعرض مؤشر صغير
  /// يشير إلى أن الضغط على الاسم يفتح صفحة بكل تفاصيل الفرع.
  final bool hasSubSteps;

  const _BranchTitle({
    required this.title,
    required this.accentColor,
    required this.branchNumber,
    required this.onTap,
    this.hasSubSteps = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              branchNumber == 1
                  ? Icons.check_circle_rounded
                  : Icons.alt_route_rounded,
              color: accentColor,
              size: 14,
            ),
            if (hasSubSteps) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.touch_app_rounded,
                color: accentColor.withOpacity(0.7),
                size: 12,
              ),
            ],
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FORK CONNECTOR
// ============================================================================

class _BranchForkConnector extends StatelessWidget {
  final int branchCount;
  final double laneWidth;
  final double gap;
  final Color color;

  const _BranchForkConnector({
    required this.branchCount,
    required this.laneWidth,
    required this.gap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width =
        laneWidth * branchCount +
            gap * (branchCount - 1);

    return SizedBox(
      width: width,
      height: 62,
      child: CustomPaint(
        painter: _ForkPainter(
          branchCount: branchCount,
          laneWidth: laneWidth,
          gap: gap,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// MERGE CONNECTOR
// ============================================================================

class _BranchMergeConnector extends StatelessWidget {
  final int branchCount;
  final double laneWidth;
  final double gap;
  final Color color;

  const _BranchMergeConnector({
    required this.branchCount,
    required this.laneWidth,
    required this.gap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width =
        laneWidth * branchCount +
            gap * (branchCount - 1);

    return SizedBox(
      width: width,
      height: 64,
      child: CustomPaint(
        painter: _MergePainter(
          branchCount: branchCount,
          laneWidth: laneWidth,
          gap: gap,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// PAINTER: FORK
// ============================================================================

class _ForkPainter extends CustomPainter {
  final int branchCount;
  final double laneWidth;
  final double gap;
  final Color color;

  _ForkPainter({
    required this.branchCount,
    required this.laneWidth,
    required this.gap,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (branchCount <= 0) return;

    final paint = Paint()
      ..color = color.withOpacity(0.65)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;

    for (int index = 0;
    index < branchCount;
    index++) {
      final laneCenter =
          index * (laneWidth + gap) +
              laneWidth / 2;

      final path = Path()
        ..moveTo(centerX, 0)
        ..cubicTo(
          centerX,
          size.height * 0.30,
          laneCenter,
          size.height * 0.55,
          laneCenter,
          size.height,
        );

      _drawDashedPath(
        canvas,
        path,
        paint,
      );

      _drawArrowHead(
        canvas,
        Offset(
          laneCenter,
          size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant _ForkPainter oldDelegate,
      ) {
    return oldDelegate.branchCount != branchCount ||
        oldDelegate.laneWidth != laneWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.color != color;
  }
}

// ============================================================================
// PAINTER: MERGE
// ============================================================================

class _MergePainter extends CustomPainter {
  final int branchCount;
  final double laneWidth;
  final double gap;
  final Color color;

  _MergePainter({
    required this.branchCount,
    required this.laneWidth,
    required this.gap,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (branchCount <= 0) return;

    final paint = Paint()
      ..color = color.withOpacity(0.65)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;

    for (int index = 0;
    index < branchCount;
    index++) {
      final laneCenter =
          index * (laneWidth + gap) +
              laneWidth / 2;

      final path = Path()
        ..moveTo(
          laneCenter,
          0,
        )
        ..cubicTo(
          laneCenter,
          size.height * 0.35,
          centerX,
          size.height * 0.60,
          centerX,
          size.height,
        );

      _drawDashedPath(
        canvas,
        path,
        paint,
      );

      _drawArrowHead(
        canvas,
        Offset(
          centerX,
          size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant _MergePainter oldDelegate,
      ) {
    return oldDelegate.branchCount != branchCount ||
        oldDelegate.laneWidth != laneWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.color != color;
  }
}

// ============================================================================
// VERTICAL DASHED LINE
// ============================================================================

class _DashedVerticalPainter extends CustomPainter {
  final Color color;

  const _DashedVerticalPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.65)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final x = size.width / 2;

    const dashLength = 5.0;
    const gap = 4.0;

    double y = 0;

    while (y < size.height) {
      final end = math.min(
        y + dashLength,
        size.height,
      );

      canvas.drawLine(
        Offset(x, y),
        Offset(x, end),
        paint,
      );

      y += dashLength + gap;
    }
  }

  @override
  bool shouldRepaint(
      covariant _DashedVerticalPainter oldDelegate,
      ) {
    return oldDelegate.color != color;
  }
}

// ============================================================================
// VERTICAL DASHED ARROW
// ============================================================================

class _DashedArrowPainter extends CustomPainter {
  final Color color;

  const _DashedArrowPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.65)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final x = size.width / 2;

    const dashLength = 5.0;
    const gap = 4.0;

    double y = 0;

    while (y < size.height - 10) {
      final end = math.min(
        y + dashLength,
        size.height - 10,
      );

      canvas.drawLine(
        Offset(x, y),
        Offset(x, end),
        paint,
      );

      y += dashLength + gap;
    }

    final arrowY = size.height - 2;

    canvas.drawPath(
      Path()
        ..moveTo(x - 5, arrowY - 7)
        ..lineTo(x, arrowY)
        ..lineTo(x + 5, arrowY - 7),
      paint,
    );
  }

  @override
  bool shouldRepaint(
      covariant _DashedArrowPainter oldDelegate,
      ) {
    return oldDelegate.color != color;
  }
}

// ============================================================================
// DASHED PATH
// ============================================================================

void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    ) {
  const dashLength = 5.0;
  const gap = 4.0;

  for (final metric in path.computeMetrics()) {
    double distance = 0;

    while (distance < metric.length) {
      final end = math.min(
        distance + dashLength,
        metric.length,
      );

      canvas.drawPath(
        metric.extractPath(
          distance,
          end,
        ),
        paint,
      );

      distance += dashLength + gap;
    }
  }
}

// ============================================================================
// ARROW HEAD
// ============================================================================

void _drawArrowHead(
    Canvas canvas,
    Offset point,
    Paint paint,
    ) {
  const size = 5.0;

  canvas.drawPath(
    Path()
      ..moveTo(
        point.dx - size,
        point.dy - size,
      )
      ..lineTo(
        point.dx,
        point.dy,
      )
      ..lineTo(
        point.dx + size,
        point.dy - size,
      ),
    paint,
  );
}