import '../../data/repositories/legal_repository.dart';
import '../entities/category_entity.dart';


class GetCategoriesUseCase {
  final LegalRepository repository;

  GetCategoriesUseCase(this.repository);

  Future<List<CategoryEntity>> call() async {
    return await repository.getCategories();
  }
}