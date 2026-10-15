import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/app_theme.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/roadmap_list_tile.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/step_palette.dart';

void main() {
  setUp(() => AppThemeController.isLight.value = false);
  tearDown(() => AppThemeController.isLight.value = false);

  testWidgets('app bar toggle switches theme while preserving accent icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: AppThemeController.isLight,
        builder: (context, isLight, _) => MaterialApp(
          theme: AppColors.theme,
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
      ),
    );

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(AppColors.background, AppColors.darkBackground);

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(AppThemeController.isLight.value, isTrue);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    expect(AppColors.background, AppColors.lightBackground);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.folder_open_rounded)).color,
      StepPalette.of(1).color,
    );
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
  });
}

void _noop() {}
