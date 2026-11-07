import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/features/legal_cases/presentation/screens/global_search_screen.dart';

void main() {
  testWidgets('back does not close the app when search is the root screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GlobalSearchScreen()));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('global-search-back')));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back arrow returns from global search to the previous screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const GlobalSearchScreen(),
                ),
              ),
              child: const Text('Open search'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open search'));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('global-search-back')));
    await tester.pumpAndSettle();

    expect(find.text('Open search'), findsOneWidget);
    expect(find.byType(GlobalSearchScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
