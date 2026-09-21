import 'dart:convert';
import '../../domain/entities/step_branch.dart';

class CaseStepModel {
  final String id;
  final String caseId;
  final int stepNumber;
  final String title;
  final String shortDescription;
  final List<StepBranch> branches;

  CaseStepModel({
    required this.id,
    required this.caseId,
    required this.stepNumber,
    required this.title,
    required this.shortDescription,
    this.branches = const [],
  });

  factory CaseStepModel.fromJson(Map<String, dynamic> json) {
    List<StepBranch> parsedBranches = [];
    String rawDesc = json['short_description'] ?? '';

    // Check if description encodes dynamic branches as JSON
    if (rawDesc.startsWith('__BRANCHES_JSON__')) {
      try {
        final jsonStr = rawDesc.replaceFirst('__BRANCHES_JSON__', '');
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        rawDesc = data['main_description'] ?? '';
        final list = data['branches'] as List<dynamic>?;
        if (list != null) {
          parsedBranches = list.map((b) => StepBranch.fromJson(Map<String, dynamic>.from(b))).toList();
        }
      } catch (_) {}
    }

    return CaseStepModel(
      id: json['id'],
      caseId: json['case_id'],
      stepNumber: json['step_number'],
      title: json['title'],
      shortDescription: rawDesc,
      branches: parsedBranches,
    );
  }
}