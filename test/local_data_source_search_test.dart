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
}
