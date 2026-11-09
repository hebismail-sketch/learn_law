import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:learn_law/core/ads/ad_mob_service.dart';
import 'package:learn_law/core/ads/category_unlock_store.dart';
import 'package:learn_law/core/sync/app_database.dart';
import 'package:learn_law/core/sync/connectivity_service.dart';
import 'package:learn_law/core/sync/local_data_source.dart';
import 'package:learn_law/core/sync/sync_manager.dart';
import 'package:learn_law/features/legal_cases/data/repositories/legal_repository_impl.dart';
import 'package:learn_law/features/legal_cases/domain/usecases/get_categories_usecase.dart';
import 'package:learn_law/features/legal_cases/domain/usecases/get_case_steps_usecase.dart';
import 'package:learn_law/features/legal_cases/domain/usecases/get_legal_cases_usecase.dart';
import 'package:learn_law/features/legal_cases/domain/usecases/get_subcategories_usecase.dart';
import 'package:learn_law/features/legal_cases/presentation/bloc/legal_cubit.dart';
import 'package:learn_law/features/legal_cases/presentation/screens/case_roadmap_screen.dart';
import 'package:learn_law/features/legal_cases/presentation/screens/global_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final locator = GetIt.instance;
  late AppDatabase database;
  late LocalDataSource localDataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await locator.reset();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    localDataSource = LocalDataSourceImpl(database);
    locator.registerSingleton<LocalDataSource>(localDataSource);
    locator.registerSingleton(
      SyncManager(
        db: database,
        supabase: SupabaseClient('http://localhost:54321', 'test-key'),
        connectivity: ConnectivityService(),
      ),
    );
    final repository = LegalRepositoryImpl(localDataSource: localDataSource);
    locator.registerFactory(
      () => LegalCubit(
        getCategoriesUseCase: GetCategoriesUseCase(repository),
        getSubcategoriesUseCase: GetSubcategoriesUseCase(repository),
        getLegalCasesUseCase: GetLegalCasesUseCase(repository),
        getCaseStepsUseCase: GetCaseStepsUseCase(repository),
      ),
    );
  });

  tearDown(() async {
    await locator.reset();
    await database.close();
  });

  testWidgets('unlocks a result category before opening the selected case', (
    tester,
  ) async {
    final categoryId = await localDataSource.insertCategory(
      name: 'الدعاوى المدنية',
    );
    final subcategoryId = await localDataSource.insertSubcategory(
      categoryId: categoryId,
      name: 'القسم المدني',
    );
    await localDataSource.insertLegalCase(
      subcategoryId: subcategoryId,
      title: 'قضية تجريبية',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalSearchScreen(
          rewardedAdLoader: (_) async => RewardedAdResult.earned,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'قضية تجريبية');
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pumpAndSettle();
    final searchResult = find.widgetWithText(ListTile, 'قضية تجريبية');
    expect(searchResult, findsOneWidget);

    await tester.tap(searchResult);
    await tester.pumpAndSettle();
    expect(find.text('فتح الدعاوى المدنية'), findsOneWidget);
    expect(find.byType(CaseRoadmapScreen), findsNothing);

    await tester.tap(find.text('مشاهدة إعلان وفتح التصنيف 30 يومًا'));
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(await CategoryUnlockStore().isUnlocked(categoryId), isTrue);
    expect(find.byType(CaseRoadmapScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CaseRoadmapScreen),
        matching: find.text('قضية تجريبية'),
      ),
      findsOneWidget,
    );
  });
}
