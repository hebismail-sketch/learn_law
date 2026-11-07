import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/app_theme.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/roadmap_list_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeController.initialize();
    AppThemeController.isLight.value = false;
  });
  tearDown(() => AppThemeController.isLight.value = false);

  test('restores and persists both theme selections', () async {
    SharedPreferences.setMockInitialValues({'is_light_theme': true});
    await AppThemeController.initialize();
    expect(AppThemeController.isLight.value, isTrue);

    await AppThemeController.toggle();
    expect(AppThemeController.isLight.value, isFalse);
    await AppThemeController.initialize();
    expect(AppThemeController.isLight.value, isFalse);

    await AppThemeController.toggle();
    expect(AppThemeController.isLight.value, isTrue);
    await AppThemeController.initialize();
    expect(AppThemeController.isLight.value, isTrue);
  });

  testWidgets('app bar toggle switches theme while preserving accent icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppColors.theme,
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: AppThemeController.isLight,
          builder: (context, _, _) => Theme(
            data: AppColors.theme,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: Scaffold(
          appBar: AppBar(actions: const [ThemeToggleButton()]),
          body: const RoadmapListTile(
            title: 'قضايا الأسرة',
            index: 0,
            icon: Icons.folder_open_rounded,
            onTap: _noop,
          ),
        ),
      ),
    );

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(AppColors.background, AppColors.darkBackground);
    final accentIcon = find.descendant(
      of: find.byKey(const ValueKey('roadmap-list-icon-0')),
      matching: find.byIcon(Icons.folder_open_rounded),
    );
    final accentIconColor = tester.widget<Icon>(accentIcon).color;

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(AppThemeController.isLight.value, isTrue);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    expect(AppColors.background, AppColors.lightBackground);
    expect(tester.widget<Icon>(accentIcon).color, accentIconColor);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
  });

  testWidgets('changing theme preserves the active route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppColors.theme,
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: AppThemeController.isLight,
          builder: (context, _, _) => Theme(
            data: AppColors.theme,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      key: const ValueKey('detail-page'),
                      appBar: AppBar(actions: const [ThemeToggleButton()]),
                    ),
                  ),
                ),
                child: const Text('Open detail'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-page')), findsOneWidget);

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-page')), findsOneWidget);
    expect(
      Navigator.of(
        tester.element(find.byKey(const ValueKey('detail-page'))),
      ).canPop(),
      isTrue,
    );
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('detail-page'))),
      ).brightness,
      Brightness.light,
    );
  });
}

void _noop() {}
