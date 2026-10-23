import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/roadmap_list_tile.dart';

void main() {
  testWidgets('renders a horizontal accented category card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoadmapListTile(
            title: 'قضايا الأسرة',
            subtitle: 'الزواج والطلاق والنفقة',
            index: 0,
            icon: Icons.folder_rounded,
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
    expect(decoration.borderRadius, BorderRadius.circular(24));
    expect(decoration.color, isNull);
    expect(decoration.gradient, isA<LinearGradient>());
    expect(decoration.boxShadow, hasLength(1));
    expect(find.text('الفئة 01'), findsOneWidget);
    expect(find.text('قضايا الأسرة'), findsOneWidget);
    expect(find.text('الزواج والطلاق والنفقة'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    final number = tester.widget<Container>(
      find.byKey(const ValueKey('roadmap-list-number-0')),
    );
    expect((number.decoration! as BoxDecoration).shape, BoxShape.circle);

    final icon = tester.widget<Container>(
      find.byKey(const ValueKey('roadmap-list-icon-0')),
    );
    final iconRect = tester.getRect(
      find.byKey(const ValueKey('roadmap-list-icon-0')),
    );
    expect(iconRect.width, 62);
    expect(iconRect.height, 62);
    expect(iconRect.right, lessThan(tileRect.right));
    expect(
      (icon.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(19),
    );
  });

  testWidgets('uses different accent colors for adjacent cards', (
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
                icon: Icons.folder_rounded,
                onTap: () {},
              ),
              RoadmapListTile(
                title: 'الثاني',
                index: 1,
                icon: Icons.gavel_rounded,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final first =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('roadmap-list-tile-0')),
                )
                .decoration!
            as BoxDecoration;
    final second =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('roadmap-list-tile-1')),
                )
                .decoration!
            as BoxDecoration;
    final firstBorder = first.border! as Border;
    final secondBorder = second.border! as Border;
    expect(firstBorder.top.color, isNot(secondBorder.top.color));
    expect(first.gradient, isA<LinearGradient>());
    expect(second.gradient, isA<LinearGradient>());
  });

  testWidgets('supports wider tiles on the subcategory screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoadmapListTile(
            title: 'قضايا الأسرة',
            index: 0,
            icon: Icons.folder_rounded,
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

  testWidgets('keeps the horizontal card readable in a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoadmapListTile(
            title: 'دعوى الطلاق والحقوق المالية بعد الانفصال',
            subtitle: 'إجراءات الدعوى والمستندات المطلوبة',
            index: 0,
            icon: Icons.gavel_rounded,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Icons.gavel_rounded,
      ),
      findsNWidgets(2),
    );
  });
}
