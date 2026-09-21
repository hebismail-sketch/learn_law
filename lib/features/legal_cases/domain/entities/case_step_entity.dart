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
    required this.title,
    required this.shortDescription,
    this.branches = const [],
  });
}