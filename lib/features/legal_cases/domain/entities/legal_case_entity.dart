class LegalCaseEntity {
  final String id;
  final String subcategoryId;
  final String name;
  final String? description;

  LegalCaseEntity({
    required this.id,
    required this.subcategoryId,
    required this.name,
    this.description,
  });
}