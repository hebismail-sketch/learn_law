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

  testWidgets('shows each description sentence as a separate numbered item', (
    tester,
  ) async {
    final step = CaseStepEntity(
      id: 'step-1',
      caseId: 'case-1',
      stepNumber: 1,
      title: 'إجراءات تقديم الطلب',
      shortDescription: 'تبدأ المرحلة بتقديم الطلب. ثم تتم مراجعة المستندات؟',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StepDetailScreen(
          caseName: 'قضية تجريبية',
          steps: [step],
          initialStepIndex: 0,
        ),
      ),
    );

    expect(find.text('تبدأ المرحلة بتقديم الطلب.'), findsOneWidget);
    expect(find.text('ثم تتم مراجعة المستندات؟'), findsOneWidget);
    expect(find.text('وصف المسار'), findsNothing);
    final sentenceStyle = tester
        .widget<Text>(find.text('تبدأ المرحلة بتقديم الطلب.'))
        .style!;
    expect(sentenceStyle.fontSize, 16.5);
    expect(sentenceStyle.color, Colors.white);
    expect(
      tester.getCenter(find.byKey(const ValueKey('step-tile-1'))).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('step-tile-2'))).dx,
      ),
    );
    final rightCard = tester.getRect(find.byKey(const ValueKey('step-tile-1')));
    final leftCard = tester.getRect(find.byKey(const ValueKey('step-tile-2')));
    final rightNumber = find.byKey(const ValueKey('step-number-1'));
    final leftNumber = find.byKey(const ValueKey('step-number-2'));

    expect(tester.getRect(rightNumber).right, greaterThan(rightCard.right));
    expect(tester.getRect(leftNumber).left, lessThan(leftCard.left));
    expect(
      tester.widget<Container>(rightNumber).decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.shape,
        'shape',
        BoxShape.circle,
      ),
    );
    expect(
      tester
          .widget<Container>(find.byKey(const ValueKey('steps-heading-icon')))
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.borderRadius,
        'border radius',
        BorderRadius.circular(20),
      ),
    );
  });
}
