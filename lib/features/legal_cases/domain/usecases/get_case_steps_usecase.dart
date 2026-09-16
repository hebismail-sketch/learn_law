
import '../../data/repositories/legal_repository.dart';
import '../entities/case_step_entity.dart';


class GetCaseStepsUseCase {
  final LegalRepository repository;

  GetCaseStepsUseCase(this.repository);

  Future<List<CaseStepEntity>> call(String caseId) async {
    return await repository.getCaseSteps(caseId);
  }
}