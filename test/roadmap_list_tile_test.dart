import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/app_theme.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/roadmap_list_tile.dart';

void main() {
  testWidgets('centers a polished capsule tile with a solid fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoadmapListTile(
            title: 'قضايا الأسرة',
            index: 0,
            icon: Icons.folder_open_rounded,
            onTap: () {},
          ),
        ),
      ),
    );

    final tile = find.byKey(const ValueKey('roadmap-list-tile-0'));
    final tileRect = tester.getRect(tile);
    expect(tileRect.center.dx, 400);
    expect(tileRect.width, 520);

    final decoration =
        tester.widget<Container>(tile).decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(32));
    expect(decoration.color, AppColors.darkSurface);
    expect(decoration.gradient, isNull);
    expect(decoration.boxShadow, hasLength(2));
    expect(find.text('الملف 01'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

    final iconRect = tester.getRect(
      find.byKey(const ValueKey('roadmap-list-icon-0')),
    );
    expect(iconRect.width, 70);
    expect(iconRect.height, 70);
    expect(iconRect.right, greaterThan(tileRect.right));
    expect(iconRect.left, lessThan(tileRect.right - 40));
    final iconDecoration =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byKey(const ValueKey('roadmap-list-icon-0')),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(iconDecoration.shape, BoxShape.circle);
  });

  testWidgets('uses the same dark fill for tiles with different accents', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              RoadmapListTile(
                title: 'الأول',
                index: 0,
                icon: Icons.folder_open_rounded,
                onTap: () {},
              ),
              RoadmapListTile(
                title: 'الثاني',
                index: 1,
                icon: Icons.folder_open_rounded,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    for (var index = 0; index < 2; index++) {
      final decoration =
          tester
                  .widget<Container>(
                    find.byKey(ValueKey('roadmap-list-tile-$index')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, AppColors.darkSurface);
      expect(decoration.gradient, isNull);
    }
  });

  testWidgets('supports wider tiles on the subcategory screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoadmapListTile(
            title: 'قضايا الأسرة',
            index: 0,
            icon: Icons.folder_open_rounded,
            maxWidth: 620,
            onTap: () {},
          ),
        ),
      ),
    );

    final tileRect = tester.getRect(
      find.byKey(const ValueKey('roadmap-list-tile-0')),
    );
    expect(tileRect.width, 620);
    expect(tileRect.center.dx, 400);
  });
}
