import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Throwaway visual snapshot of the welcome banner (not a real regression test).
void main() {
  setUp(() {
    AppThemeController.isLight.value = false;
    if (sl.isRegistered<SyncManager>()) sl.unregister<SyncManager>();
    sl.registerSingleton<SyncManager>(_FakeSyncManager());
  });

  testWidgets('capture welcome banner', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeLegalRepository();
    final cubit = LegalCubit(
      getCategoriesUseCase: GetCategoriesUseCase(repository),
      getSubcategoriesUseCase: GetSubcategoriesUseCase(repository),
      getLegalCasesUseCase: GetLegalCasesUseCase(repository),
      getCaseStepsUseCase: GetCaseStepsUseCase(repository),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: CategoriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Give the asset image a real event loop turn so it actually decodes.
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/mizan.png'),
        tester.element(find.byType(CategoriesScreen)),
      );
    });
    await tester.pumpAndSettle();

    final finder = find.byKey(const ValueKey('welcome-banner'));
    final rect = tester.getRect(finder);
    // Capture only the banner's own pixels, not the whole screen, so the
    // diagonal edge and the photo crop can actually be judged.
    final image = (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('welcome-banner-capture')),
      );
      return boundary.toImage(pixelRatio: 2);
    }))!;
    await expectLater(image, matchesGoldenFile('goldens/welcome_banner.png'));

    AppThemeController.isLight.value = true;
    await tester.pumpAndSettle();
    final light = (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('welcome-banner-capture')),
      );
      return boundary.toImage(pixelRatio: 2);
    }))!;
    await expectLater(
      light,
      matchesGoldenFile('goldens/welcome_banner_light.png'),
    );
    // ignore: avoid_print
    print(
      'RECT ${rect.width}x${rect.height} '
      'dark=${File('test/goldens/welcome_banner.png').existsSync()} '
      'light=${File('test/goldens/welcome_banner_light.png').existsSync()}',
    );
  });
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
