import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_backend.dart';
import 'sync/app_database.dart';
import 'sync/connectivity_service.dart';
import 'sync/local_data_source.dart';
import 'sync/sync_manager.dart';
import '../features/legal_cases/data/datasources/legal_remote_data_source.dart';
import '../features/legal_cases/data/repositories/legal_repository_impl.dart';
import '../features/legal_cases/domain/repositories/legal_repository.dart';
import '../features/legal_cases/domain/usecases/get_case_steps_usecase.dart';
import '../features/legal_cases/domain/usecases/get_categories_usecase.dart';
import '../features/legal_cases/domain/usecases/get_legal_cases_usecase.dart';
import '../features/legal_cases/domain/usecases/get_subcategories_usecase.dart';
import '../features/legal_cases/presentation/bloc/legal_cubit.dart';

final sl = GetIt.instance;

Future<void> initDependencies({
  required SupabaseClient? productionClient,
  required SupabaseClient? reviewClient,
  bool reviewOnly = false,
}) async {
  sl.registerLazySingleton<ConnectivityService>(ConnectivityService.new);
  sl.registerLazySingleton<AppBackendRegistry>(
    () => AppBackendRegistry(
      productionClient: productionClient,
      reviewClient: reviewClient,
      reviewOnly: reviewOnly,
      connectivity: sl<ConnectivityService>(),
    ),
  );

  sl.registerFactory(
    () => LegalCubit(
      getCategoriesUseCase: sl(),
      getSubcategoriesUseCase: sl(),
      getLegalCasesUseCase: sl(),
      getCaseStepsUseCase: sl(),
    ),
  );

  sl.registerFactory(() => GetCategoriesUseCase(sl()));
  sl.registerFactory(() => GetSubcategoriesUseCase(sl()));
  sl.registerFactory(() => GetLegalCasesUseCase(sl()));
  sl.registerFactory(() => GetCaseStepsUseCase(sl()));

  sl.registerFactory<LegalRepository>(
    () => LegalRepositoryImpl(localDataSource: sl()),
  );
  sl.registerFactory<LegalRemoteDataSource>(
    () => LegalRemoteDataSourceImpl(
      supabaseClient: sl<AppBackendRegistry>().client,
    ),
  );
  sl.registerFactory<AppDatabase>(() => sl<AppBackendRegistry>().database);
  sl.registerFactory<LocalDataSource>(
    () => sl<AppBackendRegistry>().localDataSource,
  );
  sl.registerFactory<SyncManager>(() => sl<AppBackendRegistry>().syncManager);
}
