import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/app_ui_scale.dart';

void main() {
  group('AppUiScale', () {
    test('phone-sized windows keep the unscaled layout', () {
      expect(AppUiScale.scaleOf(const Size(360, 800)), 1.0);
      expect(AppUiScale.scaleOf(const Size(480, 960)), 1.0);
 expect(AppUiScale.scaleOf(const Size(800, 360)), 1.0);
    });

    test('tablets scale up with the shortest side', () {
      // 960x600 tablet portrait: shortest side 600 -> 600/480 = 1.25.
      expect(AppUiScale.scaleOf(const Size(960, 600)), closeTo(1.25, 1e-9));
      // Landscape keeps the same zoom: shortest side is still 600.
      expect(AppUiScale.scaleOf(const Size(600, 960)), closeTo(1.25, 1e-9));
      // 1280x800 tablet landscape: 800/480.
      expect(AppUiScale.scaleOf(const Size(1280, 800)), closeTo(800 / 480, 1e-9));
    });

    test('oversized surfaces stop at the maximum zoom', () {
      expect(AppUiScale.scaleOf(const Size(3840, 2160)), AppUiScale.clampScale(99));
      expect(AppUiScale.clampScale(0.5), 1.0);
    });

    testWidgets('scaled MediaQuery enlarges text and layout', (tester) async {
      late MediaQueryData captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800), textScaleFactor: 1.0),
          child: Builder(
            builder: (context) => AppUiScale.applyScale(
              context: context,
              child: Builder(
                builder: (inner) {
                  captured = MediaQuery.of(inner);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(captured.size.width, closeTo(1200 * (800 / 480), 1e-6));
      expect(captured.textScaleFactor, closeTo(800 / 480, 1e-6));
      expect(captured.textScaler.scale(14), closeTo(14 * (800 / 480), 1e-6));
    });

    testWidgets('unscaled devices pass the media query through untouched', (
      tester,
    ) async {
      const original = MediaQueryData(size: Size(412, 915), textScaleFactor: 1.3);
      late MediaQueryData captured;
      await tester.pumpWidget(
        MediaQuery(
          data: original,
          child: Builder(
            builder: (context) => AppUiScale.applyScale(
              context: context,
              child: Builder(
                builder: (inner) {
                  captured = MediaQuery.of(inner);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(captured.size, original.size);
      expect(captured.textScaleFactor, original.textScaleFactor);
    });
  });
}
