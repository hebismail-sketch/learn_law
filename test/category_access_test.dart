import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/ads/ad_mob_service.dart';

void main() {
  test('uses Google test inventory for interstitial ads', () {
    expect(
      AdMobService.interstitialAdUnitId,
      'ca-app-pub-3940256099942544/1033173712',
    );
  });

  test('uses Google test inventory for banner and app-open ads', () {
    expect(
      AdMobService.bannerAdUnitId,
      'ca-app-pub-3940256099942544/6300978111',
    );
    expect(
      AdMobService.appOpenAdUnitId,
      'ca-app-pub-3940256099942544/9257395921',
    );
  });

  testWidgets('continues navigation when no interstitial is ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AdMobService.pushWithInterstitial<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Center(child: Text('Destination'))),
                ),
              ),
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Destination'), findsOneWidget);
  });
}
