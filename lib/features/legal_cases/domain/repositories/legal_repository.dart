import 'package:learn_law/features/legal_cases/domain/entities/case_step_entity.dart';
import 'package:learn_law/features/legal_cases/domain/entities/category_entity.dart';
import 'package:learn_law/features/legal_cases/domain/entities/legal_case_entity.dart';
import 'package:learn_law/features/legal_cases/domain/entities/subcategory_entity.dart';




abstract class LegalRepository {
  Future<List<CategoryEntity>> getCategories();
  Future<List<SubcategoryEntity>> getSubcategories(String categoryId);
  Future<List<LegalCaseEntity>> getLegalCases(String subcategoryId);
  Future<List<CaseStepEntity>> getCaseSteps(String caseId);
}