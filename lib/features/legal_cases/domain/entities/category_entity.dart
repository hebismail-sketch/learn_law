class CategoryEntity {
  final String id;
  final String name;
  final String? description;

  CategoryEntity({
    required this.id,
    required this.name,
    this.description,
  });
}