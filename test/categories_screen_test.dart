import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/app_theme.dart';
import 'package:learn_law/core/injection_container.dart';
import 'package:learn_law/core/sync/sync_manager.dart';
import 'package:learn_law/core/sync/sync_types.dart';
import 'package:learn_law/features/legal_cases/domain/entities/case_step_entity.dart';
import 'package:learn_law/features/legal_cases/domain/entities/category_entity.dart';
import 'package:learn_law/features/legal_cases/domain/entities/legal_case_entity.dart';
import 'package:learn_law/features/legal_cases/domain/entities/subcategory_entity.dart';
import 'package:learn_law/features/legal_cases/domain/repositories/legal_repository.dart';
import 'package:learn_law/features/legal_cases/domain/usecases/get_case_steps_usecase.dart';
import 'package:learn_law/features/legal_cases/domain/usecases/get_categories_usecase.dart';
import 'package:learn_law/features/legal_cases/domain/usecases/get_legal_cases_usecase.dart';
import 'package:learn_law/features/legal_cases/domain/usecases/get_subcategories_usecase.dart';
import 'package:learn_law/features/legal_cases/presentation/bloc/legal_cubit.dart';
import 'package:learn_law/features/legal_cases/presentation/screens/categories_screen.dart';
import 'package:learn_law/features/legal_cases/presentation/state/legal_case_favorites.dart';

void main() {
  setUp(() {
    AppThemeController.isLight.value = false;
    if (sl.isRegistered<SyncManager>()) sl.unregister<SyncManager>();
    sl.registerSingleton<SyncManager>(_FakeSyncManager());
  });
  tearDown(() async {
    AppThemeController.isLight.value = false;
    await sl.unregister<SyncManager>();
  });

  testWidgets('renders the redesigned home and supports favorites', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = _createCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: CategoriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('دليل المحاماة'), findsOneWidget);
    expect(find.text('ابدأ رحلتك في عالم'), findsOneWidget);
    expect(find.text('المحاماة'), findsOneWidget);
    expect(find.text('دعوى الأحوال الشخصية'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    final bannerRect = tester.getRect(
      find.byKey(const ValueKey('welcome-banner')),
    );
    expect(bannerRect.height, 186);
    expect(bannerRect.width, 366);
    expect(tester.takeException(), isNull);

    final firstCategory = find.byKey(const ValueKey('home-category-family'));
    await tester.ensureVisible(firstCategory);
    await tester.pumpAndSettle();
    await tester.longPress(firstCategory);
    await tester.pumpAndSettle();
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle();

    expect(find.text('دعوى الأحوال الشخصية'), findsOneWidget);
    expect(find.text('الدعاوى المدنية'), findsNothing);
    expect(find.text('اضغط مطولاً على أي تصنيف لإضافته إلى هنا'), findsNothing);
  });

  testWidgets('adapts the home to the light theme', (tester) async {
    AppThemeController.isLight.value = true;
    final cubit = _createCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: CategoriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(AppColors.background, AppColors.lightBackground);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows and removes favorited legal cases from favorites', (
    tester,
  ) async {
    final legalCase = LegalCaseEntity(
      id: 'case-1',
      subcategoryId: 'family',
      name: 'دعوى نفقة',
      description: 'إجراءات دعوى النفقة',
    );
    LegalCaseFavorites.instance.toggle(legalCase);
    addTearDown(() {
      if (LegalCaseFavorites.instance.contains(legalCase.id)) {
        LegalCaseFavorites.instance.toggle(legalCase);
      }
    });

    final cubit = _createCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: CategoriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('favorite-case-case-1')), findsOneWidget);
    expect(find.text('دعوى نفقة'), findsOneWidget);
    expect(find.byTooltip('إزالة من المفضلة'), findsOneWidget);

    await tester.tap(find.byTooltip('إزالة من المفضلة'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('favorite-case-case-1')), findsNothing);
    expect(find.text('لا توجد عناصر في المفضلة بعد'), findsOneWidget);
  });
}

LegalCubit _createCubit() {
  final repository = _FakeLegalRepository();
  return LegalCubit(
    getCategoriesUseCase: GetCategoriesUseCase(repository),
    getSubcategoriesUseCase: GetSubcategoriesUseCase(repository),
    getLegalCasesUseCase: GetLegalCasesUseCase(repository),
    getCaseStepsUseCase: GetCaseStepsUseCase(repository),
  );
}

class _FakeLegalRepository implements LegalRepository {
  @override
  Future<List<CategoryEntity>> getCategories() async => [
    CategoryEntity(
      id: 'family',
      name: 'دعوى الأحوال الشخصية',
      description: 'قضايا الأسرة والزواج والطلاق والنفقة وغيرها',
    ),
    CategoryEntity(
      id: 'civil',
      name: 'الدعاوى المدنية',
      description: 'المنازعات المدنية والتعويضات',
    ),
  ];

  @override
  Future<List<SubcategoryEntity>> getSubcategories(String categoryId) async =>
      [];

  @override
  Future<List<LegalCaseEntity>> getLegalCases(String subcategoryId) async => [];

  @override
  Future<List<CaseStepEntity>> getCaseSteps(String caseId) async => [];
}

class _FakeSyncManager implements SyncManager {
  @override
  Stream<SyncStatus> get status => const Stream<SyncStatus>.empty();

  @override
  Future<SyncResult> sync() async =>
      const SyncResult(status: SyncStatus.success);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
