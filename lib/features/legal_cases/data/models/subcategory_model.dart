class SubcategoryModel {
  final String id;
  final String categoryId;
  final String name;

  SubcategoryModel({
    required this.id,
    required this.categoryId,
    required this.name,
  });

  factory SubcategoryModel.fromJson(Map<String, dynamic> json) {
    return SubcategoryModel(
      id: json['id'],
      categoryId: json['category_id'],
      name: json['name'] ?? '',
    );
  }
}