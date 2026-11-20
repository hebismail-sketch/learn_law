import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import 'legal_theme_artwork.dart';

class HomeWelcomeBanner extends StatelessWidget {
  const HomeWelcomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;
    return Container(
      key: const ValueKey('welcome-banner'),
      height: 186,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF34518A).withValues(alpha: isLight ? 0.3 : 0.7),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? const [Color(0xFFEAF1FC), Color(0xFFDCE7F7), Color(0xFFE9EEF7)]
              : const [Color(0xFF172D5E), Color(0xFF111D3A), Color(0xFF0D1930)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4013264B),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: RepaintBoundary(
        key: const ValueKey('welcome-banner-capture'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Solid panel base so the diagonal seam reads against a real colour.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: isLight
                      ? const [
                          Color(0xFFEAF1FC),
                          Color(0xFFDCE7F7),
                          Color(0xFFE4ECF8),
                        ]
                      : const [
                          Color(0xFF16284C),
                          Color(0xFF111D3A),
                          Color(0xFF13223F),
                        ],
                ),
              ),
            ),
            // Photo sits on the right, behind everything, cut by a diagonal edge.
            const _BannerArtwork(),
            // Decorative glows sit under the text column only (left side), so
            // they never wash over the photo like they did before.
            Positioned(
              left: -48,
              bottom: -68,
              child: Transform.rotate(
                angle: -0.45,
                child: Container(
                  width: 190,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6754D8).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(54),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -10,
              bottom: -30,
              child: Transform.rotate(
                angle: 0.35,
                child: Container(
                  width: 130,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6BE8).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(46),
                  ),
                ),
              ),
            ),
            Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  flex: 12,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      10,
                      10,
                      10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ابدأ رحلتك في عالم',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF17243A)
                                : Colors.white,
                            fontSize: 19,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'المحاماة',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Color(0xFFE9B96E),
                            fontSize: 27,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'استكشف جميع التصنيفات القانونية\nبسهولة وتنظيم.',
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF475569)
                                : const Color(
                                    0xFFBDCCE2,
                                  ).withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 42,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9B96E),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Expanded(flex: 9, child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo panel on the right of the welcome banner.
///
/// The left edge is a straight diagonal running top-right → bottom-left, so the
/// photo rises to the left exactly like the mockup. The photo is fully opaque:
/// the diagonal edge itself is the seam, no fade.
class _BannerArtwork extends StatelessWidget {
  const _BannerArtwork();

  static const _assetPath = 'assets/images/mizan.png';

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;

    return Positioned.fill(
      child: ClipPath(
        clipper: _SlantedLeftEdgeClipper(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Keep the full photo visible inside the slanted right-hand panel.
            FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: 0.55,
              child: LegalThemeArtwork(
                child: Image.asset(
                  _assetPath,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) => ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0x22000000),
                      BlendMode.srcATop,
                    ),
                    child: const _LegalIllustration(),
                  ),
                ),
              ),
            ),
            // Slight darkening in the dark theme so the gold scale keeps the same
            // contrast against the panel as in the mockup.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(
                        0xFF0B1730,
                      ).withValues(alpha: isLight ? 0.0 : 0.12),
                      const Color(
                        0xFF0B1730,
                      ).withValues(alpha: isLight ? 0.0 : 0.26),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Straight diagonal left edge: the photo's top edge starts further left than
/// its bottom edge, so the panel rises towards the top — like the mockup.
class _SlantedLeftEdgeClipper extends CustomClipper<Path> {
  /// Where the top edge starts (fraction of width).
  /// Where the top edge starts (fraction of width) — further right, so the
  /// diagonal climbs from bottom-left to top-right like the mockup.
  static const _topInset = 0.46;

  /// Where the bottom edge starts (fraction of width) — further left.
  static const _bottomInset = 0.20;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * _topInset, 0)
      ..lineTo(size.width * _bottomInset, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LegalIllustration extends StatelessWidget {
  const _LegalIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: const Color(0xFF89A1C7).withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 22,
          child: Icon(
            Icons.eco_rounded,
            size: 62,
            color: const Color(0xFF537C69).withValues(alpha: 0.38),
          ),
        ),
        Positioned(
          left: 4,
          right: 8,
          bottom: 22,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF162744), Color(0xFF0B1425)],
              ),
              border: Border.all(color: const Color(0xFFAE854F), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88050B15),
                  blurRadius: 12,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_stories_rounded,
                color: Color(0xFFD0A66A),
                size: 24,
              ),
            ),
          ),
        ),
        Positioned(
          left: 22,
          bottom: 12,
          child: Transform.rotate(
            angle: -0.12,
            child: Container(
              width: 76,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD7B37E),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.balance_rounded,
            size: 96,
            color: const Color(0xFFD0A66A).withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
