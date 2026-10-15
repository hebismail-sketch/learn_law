import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import 'step_palette.dart';

class RoadmapListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int index;
  final IconData icon;
  final VoidCallback onTap;
  final double maxWidth;
  final List<Widget> actions;

  const RoadmapListTile({
    super.key,
    required this.title,
    required this.index,
    required this.icon,
    required this.onTap,
    this.maxWidth = 520,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final accent = StepPalette.of(index + 1);
    final itemNumber = (index + 1).toString().padLeft(2, '0');
    final isLight = AppThemeController.isLight.value;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          key: ValueKey('roadmap-list-tile-$index'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: accent.color.withValues(alpha: isLight ? 0.20 : 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: (isLight ? accent.glow : Colors.black).withValues(
                  alpha: isLight ? 0.10 : 0.26,
                ),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accent.color.withValues(alpha: isLight ? 0.06 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(32),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  splashColor: accent.color.withValues(alpha: 0.10),
                  highlightColor: accent.color.withValues(alpha: 0.04),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 74,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.color.withValues(
                              alpha: isLight ? 0.10 : 0.14,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.color.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            'الملف $itemNumber',
                            style: TextStyle(
                              color: isLight ? accent.glow : accent.color,
                              fontSize: 11,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (actions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4,
                            children: actions,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.raisedSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    key: ValueKey('roadmap-list-icon-$index'),
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.raisedSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.color.withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.color.withValues(
                            alpha: isLight ? 0.16 : 0.25,
                          ),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.color.withValues(
                          alpha: isLight ? 0.12 : 0.18,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent.color, size: 26),
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
}
