class LegalCaseModel {
  final String id;
  final String subcategoryId;
  final String name;
  final String? description;

  LegalCaseModel({
    required this.id,
    required this.subcategoryId,
    required this.name,
    this.description,
  });

  factory LegalCaseModel.fromJson(Map<String, dynamic> json) {
    return LegalCaseModel(
      id: json['id'],
      subcategoryId: json['subcategory_id'],
      name: json['name'] ?? '',
      description: json['description'],
    );
  }
}