import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

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

  static const _accentColors = [
    Color(0xFF13C9B5),
    Color(0xFF08AEEF),
    Color(0xFF9853F0),
    Color(0xFFE53E9F),
    Color(0xFFFFAA32),
    Color(0xFF00BBD4),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _accentColors[index % _accentColors.length];
    final glow = Color.lerp(accent, Colors.white, 0.12)!;
    final itemNumber = (index + 1).toString().padLeft(2, '0');
    final isLight = AppThemeController.isLight.value;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          key: ValueKey('roadmap-list-tile-$index'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withValues(alpha: isLight ? 0.72 : 0.88),
              width: 1.4,
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.alphaBlend(
                  accent.withValues(alpha: isLight ? 0.06 : 0.17),
                  AppColors.surface,
                ),
                AppColors.surface,
                Color.alphaBlend(
                  accent.withValues(alpha: isLight ? 0.11 : 0.24),
                  AppColors.surface,
                ),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: (isLight ? glow : Colors.black).withValues(
                  alpha: isLight ? 0.08 : 0.22,
                ),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashColor: accent.withValues(alpha: 0.10),
              highlightColor: accent.withValues(alpha: 0.04),
              child: Stack(
                children: [
                  PositionedDirectional(
                    end: 76,
                    top: -20,
                    bottom: -20,
                    child: IgnorePointer(
                      child: Icon(
                        icon,
                        size: 132,
                        color: accent.withValues(
                          alpha: isLight ? 0.035 : 0.065,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        Container(
                          key: ValueKey('roadmap-list-number-$index'),
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.6),
                              width: 1.3,
                            ),
                          ),
                          child: Text(
                            itemNumber,
                            style: TextStyle(
                              color: glow,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  'الفئة $itemNumber',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: glow,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  height: 1.3,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (subtitle != null &&
                                  subtitle!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (actions.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 4,
                                  children: actions,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          key: ValueKey('roadmap-list-icon-$index'),
                          width: 62,
                          height: 62,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(
                              alpha: isLight ? 0.17 : 0.28,
                            ),
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.6),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(
                                  alpha: isLight ? 0.12 : 0.22,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: glow, size: 30),
                        ),
                        const SizedBox(width: 9),
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.raisedSurface.withValues(
                              alpha: isLight ? 0.85 : 0.72,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: glow,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
