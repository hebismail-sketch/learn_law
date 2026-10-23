import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

class SubcategoryListTile extends StatelessWidget {
  const SubcategoryListTile({
    super.key,
    required this.title,
    required this.index,
    required this.onTap,
    this.maxWidth = 620,
  });

  final String title;
  final int index;
  final VoidCallback onTap;
  final double maxWidth;

  static const _accentColors = [
    Color(0xFF00C8B2),
    Color(0xFF2676FF),
    Color(0xFF8B4DFA),
    Color(0xFFE13BAA),
    Color(0xFFFF9800),
    Color(0xFF00B9CB),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _accentColors[index % _accentColors.length];
    final itemNumber = (index + 1).toString().padLeft(2, '0');
    final isLight = AppThemeController.isLight.value;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          key: ValueKey('subcategory-list-tile-$index'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withValues(alpha: isLight ? 0.45 : 0.32),
            ),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Color.alphaBlend(
                  accent.withValues(alpha: isLight ? 0.08 : 0.07),
                  AppColors.surface,
                ),
                Color.alphaBlend(
                  accent.withValues(alpha: isLight ? 0.025 : 0.03),
                  AppColors.surface,
                ),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isLight ? 0.08 : 0.09),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashColor: accent.withValues(alpha: 0.12),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(7),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      14,
                      10,
                      18,
                      10,
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          width: 68,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(
                              alpha: isLight ? 0.12 : 0.14,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.62),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(
                                  alpha: isLight ? 0.08 : 0.1,
                                ),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.folder_outlined,
                            color: Color.lerp(accent, Colors.white, 0.38),
                            size: 35,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  'القسم $itemNumber',
                                  style: TextStyle(
                                    color: Color.lerp(
                                      accent,
                                      Colors.white,
                                      0.38,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                title,
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'استكشف الدعاوى',
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 9),
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.raisedSurface.withValues(
                              alpha: isLight ? 0.9 : 0.75,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFF617497,
                              ).withValues(alpha: isLight ? 0.3 : 0.45),
                            ),
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: AppColors.textPrimary,
                            size: 26,
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
