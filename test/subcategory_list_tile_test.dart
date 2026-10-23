import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/subcategory_list_tile.dart';

void main() {
  testWidgets('renders screenshot-style category card and handles taps', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubcategoryListTile(
            title: 'دعوى الطلاق وإنهاء العلاقة الزوجية',
            index: 0,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('القسم 01'), findsOneWidget);
    expect(find.text('دعوى الطلاق وإنهاء العلاقة الزوجية'), findsOneWidget);
    expect(find.text('استكشف الدعاوى'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('subcategory-list-tile-0')))
          .height,
      lessThanOrEqualTo(110),
    );

    await tester.tap(find.byKey(const ValueKey('subcategory-list-tile-0')));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps long titles readable on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubcategoryListTile(
            title: 'دعوى المتعة والحقوق المالية بعد الطلاق',
            index: 4,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('القسم 05'), findsOneWidget);
  });
}
