import '../../domain/entities/category_entity.dart';

abstract class LegalState {}

class LegalInitial extends LegalState {}

class LegalLoading extends LegalState {}

class CategoriesLoaded extends LegalState {
  final List<CategoryEntity> categories;
  CategoriesLoaded(this.categories);
}

class LegalError extends LegalState {
  final String message;
  LegalError(this.message);
}