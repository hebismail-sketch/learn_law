import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/ads/ad_mob_service.dart';

void main() {
  testWidgets('continues to the app when the startup ad never completes', (
    tester,
  ) async {
    final pendingAd = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: AppOpenAdStartupGate(
          startupAdLoader: () => pendingAd.future,
          child: const Text('App ready'),
        ),
      ),
    );

    expect(find.text('App ready'), findsNothing);
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('App ready'), findsOneWidget);
    pendingAd.complete();
  });

  testWidgets('continues to the app when startup ad loading throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppOpenAdStartupGate(
          startupAdLoader: () async => throw StateError('ad unavailable'),
          child: const Text('App ready'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('App ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
