import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';
import '../models/subcategory_model.dart';
import '../models/legal_case_model.dart';
import '../models/case_step_model.dart';

abstract class LegalRemoteDataSource {
  Future<List<CategoryModel>> getCategories();
  Future<List<SubcategoryModel>> getSubcategories(String categoryId);
  Future<List<LegalCaseModel>> getLegalCases(String subcategoryId);
  Future<List<CaseStepModel>> getCaseSteps(String caseId);
}

class LegalRemoteDataSourceImpl implements LegalRemoteDataSource {
  final SupabaseClient supabaseClient;

  LegalRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await supabaseClient.from('categories').select();
    return (response as List)
        .map((data) => CategoryModel.fromJson(data))
        .toList();
  }

  @override
  Future<List<SubcategoryModel>> getSubcategories(String categoryId) async {
    final response = await supabaseClient
        .from('subcategories')
        .select()
        .eq('category_id', categoryId);
    return (response as List)
        .map((data) => SubcategoryModel.fromJson(data))
        .toList();
  }

  @override
  Future<List<LegalCaseModel>> getLegalCases(String subcategoryId) async {
    final response = await supabaseClient
        .from('legal_cases')
        .select()
        .eq('subcategory_id', subcategoryId);
    return (response as List)
        .map((data) => LegalCaseModel.fromJson(data))
        .toList();
  }

  @override
  Future<List<CaseStepModel>> getCaseSteps(String caseId) async {
    final response = await supabaseClient
        .from('case_steps')
        .select()
        .eq('case_id', caseId)
        .order('step_number', ascending: true);
    return (response as List)
        .map((data) => CaseStepModel.fromJson(data))
        .toList();
  }
}