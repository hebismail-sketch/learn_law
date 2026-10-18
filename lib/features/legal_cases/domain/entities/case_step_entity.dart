import '../../../../core/legal_text.dart';
import 'step_branch.dart';

class CaseStepEntity {
  final String id;
  final String caseId;
  final int stepNumber;
  final String title;
  final String shortDescription;
  final List<StepBranch> branches;

  CaseStepEntity({
    required this.id,
    required this.caseId,
    required this.stepNumber,
    required String title,
    required String shortDescription,
    this.branches = const [],
  }) : title = stripLegalTextSymbols(title),
       shortDescription = stripLegalTextSymbols(shortDescription);
}
