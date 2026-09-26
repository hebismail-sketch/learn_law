import '../../../../core/sync/app_database.dart';
import '../../domain/entities/case_step_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../../domain/entities/subcategory_entity.dart';
import 'case_step_model.dart';

/// Converts the Drift row types into the domain entities the UI consumes.
///
/// These are plain functions rather than extensions: four extensions that all
/// expose `toEntity` cannot be resolved by the compiler when the receiver type
/// comes from a generated file, and distinct names make each call site say
/// which entity it produces.
///
/// The domain layer must not know about SQLite, so the translation stops here
/// at the data layer boundary.
CategoryEntity categoryToEntity(LocalCategory row) => CategoryEntity(
      id: row.id,
      name: row.name,
      description: row.description,
    );

SubcategoryEntity subcategoryToEntity(LocalSubcategory row) => SubcategoryEntity(
      id: row.id,
      categoryId: row.categoryId,
      name: row.name,
    );

LegalCaseEntity legalCaseToEntity(LocalLegalCase row) => LegalCaseEntity(
      id: row.id,
      subcategoryId: row.subcategoryId,
      // The local column is `title`, matching Supabase. The entity calls it
      // `name`, so the rename belongs here and not in the entity.
      name: row.title,
      description: row.description,
    );

CaseStepEntity caseStepToEntity(LocalCaseStep row) {
  // The branch payload travels inside short_description as a
  // __BRANCHES_JSON__ blob, exactly as it does in Supabase. Handing the row to
  // the existing model parser keeps a single implementation of that format
  // instead of a second copy that could drift out of step with it.
  final model = CaseStepModel.fromJson(<String, dynamic>{
    'id': row.id,
    'case_id': row.caseId,
    'step_number': row.stepNumber,
    'title': row.title,
    'short_description': row.shortDescription,
  });

  return CaseStepEntity(
    id: model.id,
    caseId: model.caseId,
    stepNumber: model.stepNumber,
    title: model.title,
    shortDescription: model.shortDescription,
    branches: model.branches,
  );
}
