import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/legal_text.dart';
import 'package:learn_law/features/legal_cases/data/models/case_step_model.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/legal_text_input_formatter.dart';

void main() {
  test(
    'removes symbols while preserving Arabic legal prose and punctuation',
    () {
      expect(stripLegalTextSymbols('**#دعوى نفقة # ٢٠٢٤**'), 'دعوى نفقة  ٢٠٢٤');
      expect(
        stripLegalTextSymbols('تُقبل الدعوى، وفقاً للمادة ١٠.'),
        'تُقبل الدعوى، وفقاً للمادة ١٠.',
      );
      expect(stripLegalTextSymbols('رقم ١٠/٢٠ @ الدعوى'), 'رقم ١٠٢٠  الدعوى');
    },
  );

  test('cleans case steps and recursively decoded branch text', () {
    final step = CaseStepModel.fromJson({
      'id': 'step-1',
      'case_id': 'case-1',
      'step_number': 1,
      'title': '# تقديم * الطلب',
      'short_description':
          '__BRANCHES_JSON__${jsonEncode({
            'main_description': '**مراجعة # المستندات**',
            'branches': [
              {
                'title': '# قبول * الدعوى',
                'description': '**تحديد # الجلسة**',
                'sub_steps': ['* إخطار # الخصم'],
                'branches': [
                  {
                    'title': '# فرع تابع',
                    'description': '* استكمال الإجراء',
                    'sub_steps': ['# إجراء إضافي'],
                  },
                ],
              },
            ],
          })}',
    });

    expect(step.title, ' تقديم  الطلب');
    expect(step.shortDescription, 'مراجعة  المستندات');
    expect(step.branches.single.title, ' قبول  الدعوى');
    expect(step.branches.single.description, 'تحديد  الجلسة');
    expect(step.branches.single.subSteps.single, ' إخطار  الخصم');
    expect(
      step.branches.single.branches.single.subSteps.single,
      ' إجراء إضافي',
    );
  });

  test('cleans text inside stored branch JSON without breaking its format', () {
    final stored = stripLegalTextSymbolsFromStepDescription(
      '__BRANCHES_JSON__${jsonEncode({
        'main_description': '**مراجعة # المستندات**',
        'branches': [
          {
            'title': '* قبول الدعوى',
            'description': '# تحديد الجلسة',
            'sub_steps': ['* إخطار الخصم'],
            'outcome': 'acceptance',
          },
        ],
        'path_links': [
          {'step_title': '* قبول الدعوى', 'next_step': 2},
        ],
      })}',
    );
    final decoded = jsonDecode(stored.substring('__BRANCHES_JSON__'.length));

    expect(decoded['main_description'], 'مراجعة  المستندات');
    expect(decoded['branches'][0]['title'], ' قبول الدعوى');
    expect(decoded['branches'][0]['description'], ' تحديد الجلسة');
    expect(decoded['branches'][0]['sub_steps'], [' إخطار الخصم']);
    expect(decoded['branches'][0]['outcome'], 'acceptance');
    expect(decoded['path_links'][0]['step_title'], ' قبول الدعوى');
    expect(decoded['path_links'][0]['next_step'], 2);
  });

  testWidgets('removes symbols immediately when typing in a legal text field', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            inputFormatters: [legalTextInputFormatter],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'دعوى **نفقة** #صغار');

    expect(controller.text, 'دعوى نفقة صغار');
  });
}
