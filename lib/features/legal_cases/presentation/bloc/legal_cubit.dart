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
      if (isClosed) return;
      emit(CategoriesLoaded(categories));
    } catch (e) {
      if (isClosed) return;
      emit(LegalError(e.toString()));
    }
  }

  Future<void> fetchSubcategories(String categoryId) async {
    emit(LegalLoading());
    try {
      final subcategories = await getSubcategoriesUseCase(categoryId);
      if (isClosed) return;
      emit(SubcategoriesLoaded(subcategories));
    } catch (e) {
      if (isClosed) return;
      emit(LegalError(e.toString()));
    }
  }

  Future<void> fetchLegalCases(String subcategoryId) async {
    emit(LegalLoading());
    try {
      final cases = await getLegalCasesUseCase(subcategoryId);
      if (isClosed) return;
      emit(LegalCasesLoaded(cases));
    } catch (e) {
      if (isClosed) return;
      emit(LegalError(e.toString()));
    }
  }

  Future<void> fetchCaseSteps(String caseId) async {
    emit(LegalLoading());
    try {
      final steps = await getCaseStepsUseCase(caseId);
      if (isClosed) return;
      emit(CaseStepsLoaded(steps));
    } catch (e) {
      if (isClosed) return;
      emit(LegalError(e.toString()));
    }
  }

  Future<void> refreshCategories() async {
    final categories = await getCategoriesUseCase();
    if (isClosed) return;
    emit(CategoriesLoaded(categories));
  }

  Future<void> refreshSubcategories(String categoryId) async {
    final subcategories = await getSubcategoriesUseCase(categoryId);
    if (isClosed) return;
    emit(SubcategoriesLoaded(subcategories));
  }

  Future<void> refreshLegalCases(String subcategoryId) async {
    final cases = await getLegalCasesUseCase(subcategoryId);
    if (isClosed) return;
    emit(LegalCasesLoaded(cases));
  }

  Future<void> refreshCaseSteps(String caseId) async {
    final steps = await getCaseStepsUseCase(caseId);
    if (isClosed) return;
    emit(CaseStepsLoaded(steps));
  }
}
