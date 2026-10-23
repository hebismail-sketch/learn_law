import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/legal_browse_header.dart';

void main() {
  testWidgets('renders the legal list title and themed artwork banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const LegalBrowseHeaderTitle(
              title: 'دعوى الأحوال الشخصية',
              subtitle: 'اختر الدعوى التي تريد الاطلاع عليها',
              icon: Icons.folder_rounded,
            ),
          ),
          body: const LegalBrowseBanner(
            title: 'كل دعوى لها طريق واضح',
            subtitle: 'تعرف على خطوات القضية وإجراءاتها',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('دعوى الأحوال الشخصية'), findsOneWidget);
    expect(find.text('اختر الدعوى التي تريد الاطلاع عليها'), findsOneWidget);
    expect(find.text('كل دعوى لها طريق واضح'), findsOneWidget);
    expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
