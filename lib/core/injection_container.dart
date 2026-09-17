import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/legal_cases/data/datasources/legal_remote_data_source.dart';
import '../features/legal_cases/data/repositories/legal_repository_impl.dart';
import '../features/legal_cases/domain/repositories/legal_repository.dart';
import '../features/legal_cases/domain/usecases/get_categories_usecase.dart';
import '../features/legal_cases/domain/usecases/get_subcategories_usecase.dart';
import '../features/legal_cases/domain/usecases/get_legal_cases_usecase.dart';
import '../features/legal_cases/domain/usecases/get_case_steps_usecase.dart';
import '../features/legal_cases/presentation/bloc/legal_cubit.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Cubit
  sl.registerFactory(
        () => LegalCubit(
      getCategoriesUseCase: sl(),
      getSubcategoriesUseCase: sl(),
      getLegalCasesUseCase: sl(),
      getCaseStepsUseCase: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => GetCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetSubcategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetLegalCasesUseCase(sl()));
  sl.registerLazySingleton(() => GetCaseStepsUseCase(sl()));

  // Repository
  sl.registerLazySingleton<LegalRepository>(
        () => LegalRepositoryImpl(remoteDataSource: sl()),
  );

  // DataSources
  sl.registerLazySingleton<LegalRemoteDataSource>(
        () => LegalRemoteDataSourceImpl(supabaseClient: Supabase.instance.client),
  );
}