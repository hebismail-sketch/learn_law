import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Scales the whole interface so a tablet shows the same layout as a phone,
/// only drawn larger.
///
/// Flutter lays every screen out in logical pixels; on a wide device the same
/// fixed font sizes, paddings and icon sizes simply cover less of the width,
/// which is what made everything look miniature on a tablet. Wrapping the
/// navigator in a scaled [MediaQuery] multiplies every logical pixel by the
/// same factor, so a screen keeps the exact proportions it has on a phone and
/// just fills the larger surface.
///
/// The scale is derived from the shortest side of the window, capped at the
/// width of a large phone. Sizes in between interpolate smoothly, so rotating
/// a tablet or resizing a desktop window never jumps. A device never shrinks:
/// the scale bottoms out at 1.0, and `clampScale` keeps the value inside the
/// supported band no matter what a window manager reports.
abstract final class AppUiScale {
  /// Widths at or below this keep the phone layout unchanged. This matches the
  /// widest common small tablet portrait, the point where the shrink starts.
  static const _referenceWidth = 480.0;

  /// Beyond this the scale stops growing: oversized desktop windows must not
  /// turn the app into a cartoon.
  static const _maxScale = 1.9;

  /// The shortest window side decides the scale, so a rotated tablet keeps a
  /// constant zoom instead of shrinking in landscape.
  static double scaleOf(Size size) {
    final shortest = math.min(size.width, size.height);
    if (shortest <= _referenceWidth) return 1.0;
    return clampScale(shortest / _referenceWidth);
  }

  static double clampScale(double scale) =>
      scale.clamp(1.0, _maxScale).toDouble();

  /// Wraps [child] in a MediaQuery whose size and text scaling carry the
  /// factor, so every widget below reads the scaled values without knowing
  /// about this mechanism.
  static Widget applyScale({
    required BuildContext context,
    required Widget child,
  }) {
    final media = MediaQuery.of(context);
    final scale = scaleOf(media.size);
    if (scale == 1.0) return child;
    final scaled = media.size * scale;
    final scaler = _LinearTextScaler(media.textScaleFactor * scale);
    return MediaQuery(
      data: media.copyWith(
        size: scaled,
        textScaler: scaler,
        devicePixelRatio: media.devicePixelRatio,
        viewPadding: _scaleEdges(media.viewPadding, scale),
        padding: _scaleEdges(media.padding, scale),
        viewInsets: _scaleEdges(media.viewInsets, scale),
      ),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  static EdgeInsets _scaleEdges(EdgeInsets edges, double scale) =>
      scale == 1.0 ? edges : edges * scale;
}

/// Scales text on top of the system's own text scale, so a user font
/// preference still applies and the tablet zoom multiplies it.
class _LinearTextScaler implements TextScaler {
  const _LinearTextScaler(this._factor);

  final double _factor;

  @override
  double scale(double fontSize) => fontSize * _factor;

  @override
  double get textScaleFactor => _factor;

  @override
  TextScaler clamp({double minScaleFactor = 0.0, double maxScaleFactor = double.infinity}) =>
      _LinearTextScaler(_factor.clamp(minScaleFactor, maxScaleFactor));
}
