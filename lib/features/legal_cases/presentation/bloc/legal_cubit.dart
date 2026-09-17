import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_subcategories_usecase.dart';
import '../../domain/usecases/get_legal_cases_usecase.dart';
import '../../domain/usecases/get_case_steps_usecase.dart';
import 'legal_state.dart';

class LegalCubit extends Cubit<LegalState> {
  final GetCategoriesUseCase getCategoriesUseCase;
  final GetSubcategoriesUseCase getSubcategoriesUseCase;
  final GetLegalCasesUseCase getLegalCasesUseCase;
  final GetCaseStepsUseCase getCaseStepsUseCase;

  LegalCubit({
    required this.getCategoriesUseCase,
    required this.getSubcategoriesUseCase,
    required this.getLegalCasesUseCase,
    required this.getCaseStepsUseCase,
  }) : super(LegalInitial());

  Future<void> fetchCategories() async {
    emit(LegalLoading());
    try {
      final categories = await getCategoriesUseCase();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(LegalError(e.toString()));
    }
  }

  Future<void> fetchSubcategories(String categoryId) async {
    emit(LegalLoading());
    try {
      final subcategories = await getSubcategoriesUseCase(categoryId);
      emit(SubcategoriesLoaded(subcategories));
    } catch (e) {
      emit(LegalError(e.toString()));
    }
  }

  Future<void> fetchLegalCases(String subcategoryId) async {
    emit(LegalLoading());
    try {
      final cases = await getLegalCasesUseCase(subcategoryId);
      emit(LegalCasesLoaded(cases));
    } catch (e) {
      emit(LegalError(e.toString()));
    }
  }

  Future<void> fetchCaseSteps(String caseId) async {
    emit(LegalLoading());
    try {
      final steps = await getCaseStepsUseCase(caseId);
      emit(CaseStepsLoaded(steps));
    } catch (e) {
      emit(LegalError(e.toString()));
    }
  }
}
