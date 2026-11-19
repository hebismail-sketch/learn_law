import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/app_ui_scale.dart';

void main() {
  group('AppUiScale', () {
    test('nothing is scaled on any device', () {
      // The zoom experiment is gone: every device renders the designed
      // sizes, and tablets fit via fluid constraints instead.
      expect(AppUiScale.scaleOf(const Size(360, 800)), 1.0);
      expect(AppUiScale.scaleOf(const Size(800, 1280)), 1.0);
      expect(AppUiScale.scaleOf(const Size(2560, 1600)), 1.0);
    });

    test('content column has a sane maximum width', () {
      expect(AppUiScale.contentMaxWidth, greaterThan(600));
      expect(AppUiScale.contentMaxWidth, lessThan(900));
    });
  });
}
