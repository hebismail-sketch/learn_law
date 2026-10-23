import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:learn_law/features/legal_cases/presentation/screens/case_roadmap_screen.dart';

void main() {
  setUp(() {
    if (sl.isRegistered<SyncManager>()) sl.unregister<SyncManager>();
    sl.registerSingleton<SyncManager>(_FakeSyncManager());
  });

  tearDown(() async {
    await sl.unregister<SyncManager>();
  });

  test('ignores case-step results after the cubit is closed', () async {
    final steps = Completer<List<CaseStepEntity>>();
    final repository = _FakeLegalRepository(steps);
    final cubit = _createCubit(repository);

    final request = cubit.fetchCaseSteps('case-1');
    await Future<void>.delayed(Duration.zero);
    await cubit.close();

    steps.complete([]);
    await expectLater(request, completes);
  });

  test('ignores case-step errors after the cubit is closed', () async {
    final steps = Completer<List<CaseStepEntity>>();
    final repository = _FakeLegalRepository(steps);
    final cubit = _createCubit(repository);

    final request = cubit.fetchCaseSteps('case-1');
    await Future<void>.delayed(Duration.zero);
    await cubit.close();

    steps.completeError(StateError('request failed'));
    await expectLater(request, completes);
  });

  testWidgets('back from the roadmap is safe while local steps are loading', (
    tester,
  ) async {
    final steps = Completer<List<CaseStepEntity>>();
    final repository = _FakeLegalRepository(steps);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider(
                    create: (_) => _createCubit(repository),
                    child: CaseRoadmapScreen(
                      legalCase: LegalCaseEntity(
                        id: 'case-1',
                        subcategoryId: 'category-1',
                        name: 'قضية تجريبية',
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open case'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open case'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('قضية تجريبية'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Open case'), findsOneWidget);

    steps.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

LegalCubit _createCubit(LegalRepository repository) => LegalCubit(
  getCategoriesUseCase: GetCategoriesUseCase(repository),
  getSubcategoriesUseCase: GetSubcategoriesUseCase(repository),
  getLegalCasesUseCase: GetLegalCasesUseCase(repository),
  getCaseStepsUseCase: GetCaseStepsUseCase(repository),
);

class _FakeLegalRepository implements LegalRepository {
  _FakeLegalRepository(this.steps);

  final Completer<List<CaseStepEntity>> steps;

  @override
  Future<List<CategoryEntity>> getCategories() async => [];

  @override
  Future<List<SubcategoryEntity>> getSubcategories(String categoryId) async =>
      [];

  @override
  Future<List<LegalCaseEntity>> getLegalCases(String subcategoryId) async => [];

  @override
  Future<List<CaseStepEntity>> getCaseSteps(String caseId) => steps.future;
}

class _FakeSyncManager implements SyncManager {
  @override
  Stream<SyncStatus> get status => const Stream<SyncStatus>.empty();

  @override
  Future<int> refreshCaseSteps(String caseId) async => 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
