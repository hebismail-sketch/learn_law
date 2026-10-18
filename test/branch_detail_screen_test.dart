import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/features/legal_cases/domain/entities/step_branch.dart';
import 'package:learn_law/features/legal_cases/presentation/screens/branch_detail_screen.dart';

void main() {
  testWidgets('shows branch procedures as alternating numbered cards', (
    tester,
  ) async {
    final branch = StepBranch(
      title: 'مسار قبول الدعوى',
      description: 'تقبل المحكمة الدعوى عند استيفاء الشروط.',
      outcome: 'acceptance',
      subSteps: ['يتم فحص المستندات المقدمة.', 'تصدر المحكمة قرار القبول.'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BranchDetailScreen(caseName: 'قضية تجريبية', branch: branch),
      ),
    );

    expect(find.text('تفاصيل المسار'), findsOneWidget);
    expect(find.text('مسار قبول'), findsOneWidget);
    expect(find.text('وصف المسار'), findsNothing);
    expect(find.text('تقبل المحكمة الدعوى عند استيفاء الشروط.'), findsNothing);
    expect(find.byKey(const ValueKey('branch-detail-header')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('branch-procedures-heading')),
      findsOneWidget,
    );
    expect(find.text('يتم فحص المستندات المقدمة.'), findsOneWidget);
    expect(find.text('تصدر المحكمة قرار القبول.'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('branch-procedure-1'))).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('branch-procedure-2'))).dx,
      ),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('branch-procedure-number-1')),
          )
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.shape,
        'shape',
        BoxShape.circle,
      ),
    );
  });

  testWidgets('opens a nested branch from the branch list', (tester) async {
    final branch = StepBranch(
      title: 'المسار الرئيسي',
      description: '',
      branches: [
        StepBranch(
          title: 'المسار الفرعي',
          description: 'تفاصيل المسار الفرعي.',
          outcome: 'appeal',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BranchDetailScreen(caseName: 'قضية تجريبية', branch: branch),
      ),
    );

    await tester.tap(find.text('المسار الفرعي'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل المسار الفرعي.'), findsNothing);
    expect(find.text('مسار استئناف'), findsOneWidget);
  });
}
