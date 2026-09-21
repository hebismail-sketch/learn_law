
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/subcategory_entity.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../../domain/entities/case_step_entity.dart';
import '../../domain/repositories/legal_repository.dart';
import '../datasources/legal_remote_data_source.dart';

class LegalRepositoryImpl implements LegalRepository {
  final LegalRemoteDataSource remoteDataSource;

  LegalRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<CategoryEntity>> getCategories() async {
    final models = await remoteDataSource.getCategories();
    return models.map((model) => CategoryEntity(
      id: model.id,
      name: model.name,
      description: model.description,
    )).toList();
  }

  @override
  Future<List<SubcategoryEntity>> getSubcategories(String categoryId) async {
    final models = await remoteDataSource.getSubcategories(categoryId);
    return models.map((model) => SubcategoryEntity(
      id: model.id,
      categoryId: model.categoryId,
      name: model.name,
    )).toList();
  }

  @override
  Future<List<LegalCaseEntity>> getLegalCases(String subcategoryId) async {
    final models = await remoteDataSource.getLegalCases(subcategoryId);
    return models.map((model) => LegalCaseEntity(
      id: model.id,
      subcategoryId: model.subcategoryId,
      name: model.name,
      description: model.description,
    )).toList();
  }

  @override
  Future<List<CaseStepEntity>> getCaseSteps(String caseId) async {
    final models = await remoteDataSource.getCaseSteps(caseId);
    return models.map((model) => CaseStepEntity(
      id: model.id,
      caseId: model.caseId,
      stepNumber: model.stepNumber,
      title: model.title,
      shortDescription: model.shortDescription,
      branches: model.branches,
    )).toList();
  }
}