import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/sync/app_database.dart';
import 'package:learn_law/core/sync/local_data_source.dart';

void main() {
  late AppDatabase database;
  late LocalDataSourceImpl localDataSource;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    localDataSource = LocalDataSourceImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('search returns only cases and folders active on this device', () async {
    final categoryId = await localDataSource.insertCategory(name: 'القضايا');
    final subcategoryId = await localDataSource.insertSubcategory(
      categoryId: categoryId,
      name: 'القسم المدني',
    );
    final deletedCaseId = await localDataSource.insertLegalCase(
      subcategoryId: subcategoryId,
      title: 'قضية محذوفة',
    );
    await localDataSource.insertLegalCase(
      subcategoryId: subcategoryId,
      title: 'قضية موجودة',
    );
    await database
        .into(database.legalCases)
        .insert(
          LegalCasesCompanion.insert(
            id: 'duplicate-local-copy',
            subcategoryId: subcategoryId,
            title: 'قضية موجودة',
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    await localDataSource.deleteLegalCase(id: deletedCaseId);

    final results = await localDataSource.searchLegalCases('قضية');

    expect(results, hasLength(1));
    expect(results.single.title, 'قضية موجودة');
    expect(results.single.subcategoryName, 'القسم المدني');
  });

  test('search excludes cases in locally deleted folders', () async {
    final categoryId = await localDataSource.insertCategory(name: 'القضايا');
    final subcategoryId = await localDataSource.insertSubcategory(
      categoryId: categoryId,
      name: 'قسم محذوف',
    );
    await localDataSource.insertLegalCase(
      subcategoryId: subcategoryId,
      title: 'قضية تحت قسم محذوف',
    );

    await localDataSource.deleteSubcategory(id: subcategoryId);

    expect(await localDataSource.searchLegalCases('قضية'), isEmpty);
  });

  test('local case and step writes strip symbols before saving', () async {
    final categoryId = await localDataSource.insertCategory(name: 'القضايا');
    final subcategoryId = await localDataSource.insertSubcategory(
      categoryId: categoryId,
      name: 'القسم المدني',
    );
    final caseId = await localDataSource.insertLegalCase(
      subcategoryId: subcategoryId,
      title: '**دعوى # نفقة**',
      description: 'وصف * للقضية',
    );

    final legalCase = (await localDataSource.getLegalCases(
      subcategoryId,
    )).single;
    expect(legalCase.title, 'دعوى  نفقة');
    expect(legalCase.description, 'وصف  للقضية');

    await localDataSource.insertCaseStep(
      caseId: caseId,
      stepNumber: 1,
      title: '* تقديم الطلب',
      shortDescription:
          '__BRANCHES_JSON__${jsonEncode({
            'main_description': '**مراجعة # المستندات**',
            'branches': [
              {
                'title': '* قبول الدعوى',
                'description': '# تحديد الجلسة',
                'sub_steps': ['* إخطار الخصم'],
              },
            ],
          })}',
    );

    final step = (await localDataSource.getCaseSteps(caseId)).single;
    expect(step.title, ' تقديم الطلب');
    final data = jsonDecode(
      step.shortDescription.substring('__BRANCHES_JSON__'.length),
    );
    expect(data['main_description'], 'مراجعة  المستندات');
    expect(data['branches'][0]['title'], ' قبول الدعوى');
    expect(data['branches'][0]['description'], ' تحديد الجلسة');
    expect(data['branches'][0]['sub_steps'], [' إخطار الخصم']);
  });
}
