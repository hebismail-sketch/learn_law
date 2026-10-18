import '../../../../core/legal_text.dart';

class LegalCaseModel {
  final String id;
  final String subcategoryId;
  final String name;
  final String? description;

  LegalCaseModel({
    required this.id,
    required this.subcategoryId,
    required String name,
    String? description,
  }) : name = stripLegalTextSymbols(name),
       description = description == null
           ? null
           : stripLegalTextSymbols(description);

  factory LegalCaseModel.fromJson(Map<String, dynamic> json) {
    return LegalCaseModel(
      id: json['id'],
      subcategoryId: json['subcategory_id'],
      // Support title column from Supabase table schema
      name: json['name'] ?? json['title'] ?? '',
      description: json['description'],
    );
  }
}
