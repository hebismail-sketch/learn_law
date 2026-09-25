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
    final rawDesc = (json['short_description'] ?? '').toString();

    // Check if description encodes dynamic branches as JSON
    if (rawDesc.startsWith('__BRANCHES_JSON__')) {
      try {
        final jsonStr = rawDesc.substring('__BRANCHES_JSON__'.length);
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);
          final mainDescription = (data['main_description'] ?? '').toString();
          final list = data['branches'];
          if (list is List) {
            parsedBranches = list
                .whereType<Map>()
                .map((b) => StepBranch.fromJson(Map<String, dynamic>.from(b)))
                .toList();
          }
          // Keep the legal text visible to the editor even when its branches
          // are malformed or absent.
          return CaseStepModel(
            id: (json['id'] ?? '').toString(),
            caseId: (json['case_id'] ?? '').toString(),
            stepNumber: (json['step_number'] as num?)?.toInt() ?? 0,
            title: (json['title'] ?? '').toString(),
            shortDescription: mainDescription,
            branches: parsedBranches,
          );
        }
      } catch (_) {
        // Fall back to the original text if the embedded JSON is invalid.
      }
    }

    // قيم محصّنة: أي نوع غير متوقع من قاعدة البيانات لا يوقّع التطبيق.
    return CaseStepModel(
      id: (json['id'] ?? '').toString(),
      caseId: (json['case_id'] ?? '').toString(),
      stepNumber: (json['step_number'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      shortDescription: rawDesc,
      branches: parsedBranches,
    );
  }
}