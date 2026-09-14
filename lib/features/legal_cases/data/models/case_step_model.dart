class CaseStepModel {
  final String id;
  final String caseId;
  final int stepNumber;
  final String title;
  final String shortDescription;

  CaseStepModel({
    required this.id,
    required this.caseId,
    required this.stepNumber,
    required this.title,
    required this.shortDescription,
  });

  factory CaseStepModel.fromJson(Map<String, dynamic> json) {
    return CaseStepModel(
      id: json['id'],
      caseId: json['case_id'],
      stepNumber: json['step_number'],
      title: json['title'],
      shortDescription: json['short_description'] ?? '',
    );
  }
}