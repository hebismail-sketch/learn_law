import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/roadmap_list_tile.dart';

void main() {
  testWidgets('centers an oval dark list tile with a solid fill', (
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
    expect(decoration.borderRadius, BorderRadius.circular(36));
    expect(decoration.color, const Color(0xFF161F36));
    expect(decoration.gradient, isNull);

    final iconRect = tester.getRect(
      find.byKey(const ValueKey('roadmap-list-icon-0')),
    );
    expect(iconRect.width, 62);
    expect(iconRect.height, 62);
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
      expect(decoration.color, const Color(0xFF161F36));
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
