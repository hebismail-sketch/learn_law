
import '../../../../core/sync/local_data_source.dart';
import '../../domain/entities/case_step_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../../domain/entities/subcategory_entity.dart';
import '../../domain/repositories/legal_repository.dart';
import '../models/local_mappers.dart';

/// Serves every read from the local database and never blocks on the network.
///
/// Nothing here talks to Supabase. A pull is the sync manager's job, and it
/// will write into the same local tables this repository reads, so the UI
/// picks up new data without any change to the cubits or the screens.
class LegalRepositoryImpl implements LegalRepository {
  final LocalDataSource localDataSource;

  LegalRepositoryImpl({required this.localDataSource});

  @override
  Future<List<CategoryEntity>> getCategories() async {
    final rows = await localDataSource.getCategories();
    return rows.map(categoryToEntity).toList();
  }

  @override
  Future<List<SubcategoryEntity>> getSubcategories(String categoryId) async {
    final rows = await localDataSource.getSubcategories(categoryId);
    return rows.map(subcategoryToEntity).toList();
  }

  @override
  Future<List<LegalCaseEntity>> getLegalCases(String subcategoryId) async {
    final rows = await localDataSource.getLegalCases(subcategoryId);
    return rows.map(legalCaseToEntity).toList();
  }

  @override
  Future<List<CaseStepEntity>> getCaseSteps(String caseId) async {
    final rows = await localDataSource.getCaseSteps(caseId);
    return rows.map(caseStepToEntity).toList();
  }
}