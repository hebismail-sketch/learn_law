import '../../../../core/legal_text.dart';

class LegalCaseEntity {
  final String id;
  final String subcategoryId;
  final String name;
  final String? description;

  LegalCaseEntity({
    required this.id,
    required this.subcategoryId,
    required String name,
    String? description,
  }) : name = stripLegalTextSymbols(name),
       description = description == null
           ? null
           : stripLegalTextSymbols(description);
}
