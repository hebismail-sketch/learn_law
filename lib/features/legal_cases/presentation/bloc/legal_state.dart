import '../../domain/entities/category_entity.dart';
import '../../domain/entities/subcategory_entity.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../../domain/entities/case_step_entity.dart';

abstract class LegalState {}

class LegalInitial extends LegalState {}

class LegalLoading extends LegalState {}

class CategoriesLoaded extends LegalState {
  final List<CategoryEntity> categories;
  CategoriesLoaded(this.categories);
}

class SubcategoriesLoaded extends LegalState {
  final List<SubcategoryEntity> subcategories;
  SubcategoriesLoaded(this.subcategories);
}

class LegalCasesLoaded extends LegalState {
  final List<LegalCaseEntity> legalCases;
  LegalCasesLoaded(this.legalCases);
}

class CaseStepsLoaded extends LegalState {
  final List<CaseStepEntity> caseSteps;
  CaseStepsLoaded(this.caseSteps);
}

class LegalError extends LegalState {
  final String message;
  LegalError(this.message);
}
