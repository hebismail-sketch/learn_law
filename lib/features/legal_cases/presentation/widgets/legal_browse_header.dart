import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

class LegalBrowseHeaderTitle extends StatelessWidget {
  const LegalBrowseHeaderTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
  });

  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;

    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (icon case final icon?) ...[
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF8B5CF6,
                  ).withValues(alpha: isLight ? 0.08 : 0.18),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFB79AFF), size: 25),
          ),
        ],
      ],
    );
  }
}

class LegalBrowseBanner extends StatelessWidget {
  const LegalBrowseBanner({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;

    return Container(
      height: 100,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF7866DB).withValues(alpha: 0.55),
        ),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isLight
              ? const [Color(0xFFE6EAFE), Color(0xFFDADCF6)]
              : const [Color(0xFF1B2850), Color(0xFF282052)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF6554C8,
            ).withValues(alpha: isLight ? 0.10 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -12,
            top: -12,
            bottom: -12,
            child: Opacity(
              opacity: isLight ? 0.28 : 0.42,
              child: Image.asset(
                'assets/images/mizan.png',
                width: 190,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  const Color(0xFF181D3A).withValues(alpha: 0.04),
                  isLight
                      ? const Color(0xFFE4E8FC).withValues(alpha: 0.74)
                      : const Color(0xFF171D3D).withValues(alpha: 0.94),
                  isLight
                      ? const Color(0xFFE4E8FC).withValues(alpha: 0.98)
                      : const Color(0xFF171D3D).withValues(alpha: 0.98),
                ],
                stops: const [0, 0.52, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 12),
            child: Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: const Color(0xFF9C86FF).withValues(alpha: 0.95),
                  size: 25,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF596A99)
                              : const Color(0xFFAAB8DF),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
