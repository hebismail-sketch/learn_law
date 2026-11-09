import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/app_theme.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/legal_theme_artwork.dart';

void main() {
  setUp(() => AppThemeController.isLight.value = false);
  tearDown(() => AppThemeController.isLight.value = false);

  testWidgets('artwork lightens in light mode and restores in dark mode', (
    tester,
  ) async {
    const artworkKey = ValueKey('theme-aware-artwork');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LegalThemeArtwork(
            child: ColoredBox(
              key: artworkKey,
              color: Colors.black,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ColorFiltered), findsNothing);

    AppThemeController.isLight.value = true;
    await tester.pump();

    final filter = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
    expect(filter.colorFilter, LegalThemeArtwork.lightFilter);

    AppThemeController.isLight.value = false;
    await tester.pump();

    expect(find.byType(ColorFiltered), findsNothing);
  });
}
