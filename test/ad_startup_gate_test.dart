import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/ads/ad_mob_service.dart';

/// The startup ad may delay the first frame by at most
/// [AdMobService._startupAdTimeout]; it can never be the reason the app stays
/// closed. This is the behaviour the ads were restored to.
///
/// The first-install download is not part of this widget any more: it runs in
/// `main` before the first frame (see test/first_launch_download_test.dart).
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
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('App ready'), findsNothing);

    // The ad's own timeout (5s) releases the gate.
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
    await tester.pump();

    expect(find.text('App ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the app when the startup ad ends normally', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppOpenAdStartupGate(child: Text('App ready'))),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('App ready'), findsOneWidget);
  });
}
