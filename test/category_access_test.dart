import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/ads/ad_mob_service.dart';
import 'package:learn_law/core/ads/category_access.dart';
import 'package:learn_law/core/ads/category_unlock_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses Google test inventory for interstitial ads', () {
    expect(
      AdMobService.interstitialAdUnitId,
      'ca-app-pub-3940256099942544/1033173712',
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

  test('keeps the personal-status category free', () {
    expect(CategoryAccess.isAlwaysFree('دعوى الأحوال الشخصية'), isTrue);
    expect(CategoryAccess.isAlwaysFree('الدعاوى المدنية'), isFalse);
  });

  test('stores a category unlock for 30 days and expires it', () async {
    var now = DateTime.utc(2026, 11, 2);
    final store = CategoryUnlockStore(clock: () => now);

    expect(await store.isUnlocked('civil'), isFalse);
    expect(await store.unlockForThirtyDays('civil'), isTrue);
    expect(
      await CategoryUnlockStore(clock: () => now).isUnlocked('civil'),
      isTrue,
    );
    expect(await store.isUnlocked('criminal'), isFalse);

    now = now.add(const Duration(days: 30, seconds: 1));
    expect(await store.isUnlocked('civil'), isFalse);
  });

  testWidgets('opens the selected category after the reward is earned', (
    tester,
  ) async {
    var earnedAdCount = 0;
    bool? categoryOpened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                categoryOpened = await CategoryAccess.requestAccess(
                  context,
                  categoryId: 'civil',
                  categoryName: 'الدعاوى المدنية',
                  rewardedAdLoader: (isStillRequested) async {
                    earnedAdCount++;
                    expect(isStillRequested(), isTrue);
                    return RewardedAdResult.earned;
                  },
                );
              },
              child: const Text('فتح التصنيف'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح التصنيف'));
    await tester.pumpAndSettle();
    expect(find.text('مشاهدة إعلان وفتح التصنيف 30 يومًا'), findsOneWidget);

    await tester.tap(find.text('مشاهدة إعلان وفتح التصنيف 30 يومًا'));
    await tester.pumpAndSettle();

    expect(categoryOpened, isTrue);
    expect(earnedAdCount, 1);
    expect(await CategoryUnlockStore().isUnlocked('civil'), isTrue);
  });

  testWidgets('does not open a category when the reward was not earned', (
    tester,
  ) async {
    bool? categoryOpened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                categoryOpened = await CategoryAccess.requestAccess(
                  context,
                  categoryId: 'civil',
                  categoryName: 'الدعاوى المدنية',
                  rewardedAdLoader: (_) async => RewardedAdResult.notEarned,
                );
              },
              child: const Text('فتح التصنيف'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح التصنيف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشاهدة إعلان وفتح التصنيف 30 يومًا'));
    await tester.pumpAndSettle();

    expect(
      find.text('لم تكتمل المكافأة. شاهد الإعلان حتى يسجل AdMob إكماله.'),
      findsOneWidget,
    );
    expect(categoryOpened, isNull);

    await tester.tap(find.text('ليس الآن'));
    await tester.pumpAndSettle();
    expect(categoryOpened, isFalse);
  });
}
