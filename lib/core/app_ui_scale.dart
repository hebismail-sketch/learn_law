import 'package:flutter/material.dart';

/// Keeps the app usable on every screen size without blowing it up.
///
/// The first attempt multiplied every logical pixel by a tablet factor. That
/// kept the proportions but produced an enormous interface: a 10-inch tablet
/// drew the phone layout at more than double size and a single screen barely
/// fit. What the app actually needed is the behaviour it already had on
/// phones — fluid constraints — applied consistently:
///
///   * every list is centred at a comfortable maximum width instead of
///     stretching edge to edge on a tablet;
///   * text, icons and spacing keep their designed sizes, which read fine on a
///     large screen because the content column stays phone-width;
///   * nothing scales, so the layout cannot look "too big" on any device.
///
/// This class no longer injects a scaled MediaQuery; it exists as the home of
/// that decision and for the shared content-width constant. Do not reintroduce
/// a global zoom: it is what made tablets unusable the first time.
abstract final class AppUiScale {
  /// The widest the main content column ever gets. Phones fill it completely;
  /// tablets and desktops centre it with breathing room on both sides.
  static const double contentMaxWidth = 760;

  /// Retained for tests and callers that ask: on every device the layout is
  /// the designed size, unscaled.
  static double scaleOf(Size size) => 1.0;
}
