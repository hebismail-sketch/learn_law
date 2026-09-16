import '../../data/repositories/legal_repository.dart';
import '../entities/legal_case_entity.dart';


class GetLegalCasesUseCase {
  final LegalRepository repository;

  GetLegalCasesUseCase(this.repository);

  Future<List<LegalCaseEntity>> call(String subcategoryId) async {
    return await repository.getLegalCases(subcategoryId);
  }
}