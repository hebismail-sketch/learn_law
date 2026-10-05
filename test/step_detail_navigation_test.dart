import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/features/legal_cases/domain/entities/case_step_entity.dart';
import 'package:learn_law/features/legal_cases/presentation/screens/step_detail_screen.dart';

CaseStepEntity _step(int number, String title) => CaseStepEntity(
  id: 'step-$number',
  caseId: 'case-1',
  stepNumber: number,
  title: title,
  shortDescription: 'Description for $title.',
);

void main() {
  testWidgets('moves between steps without leaving the detail page', (
    tester,
  ) async {
    final steps = [
      _step(1, 'First step'),
      _step(2, 'Second step'),
      _step(3, 'Third step'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StepDetailScreen(
          caseName: 'Test case',
          steps: steps,
          initialStepIndex: 0,
        ),
      ),
    );

    expect(find.text('1 من 3'), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);

    await tester.tap(find.text('التالية'));
    await tester.pumpAndSettle();

    expect(find.text('2 من 3'), findsOneWidget);
    expect(find.text('Second step'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(StepDetailScreen))).canPop(),
      isFalse,
    );

    await tester.tap(find.text('السابقة'));
    await tester.pumpAndSettle();

    expect(find.text('1 من 3'), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);

    await tester.tap(find.text('التالية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالية'));
    await tester.pumpAndSettle();

    expect(find.text('3 من 3'), findsOneWidget);
    expect(find.text('Third step'), findsOneWidget);
  });
}
