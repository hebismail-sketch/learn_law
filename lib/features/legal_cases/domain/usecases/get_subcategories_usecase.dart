import '../repositories/legal_repository.dart';
import '../entities/subcategory_entity.dart';


class GetSubcategoriesUseCase {
  final LegalRepository repository;

  GetSubcategoriesUseCase(this.repository);

  Future<List<SubcategoryEntity>> call(String categoryId) async {
    return await repository.getSubcategories(categoryId);
  }
}