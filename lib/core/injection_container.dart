import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/sync/app_database.dart';
import '../core/sync/connectivity_service.dart';
import '../core/sync/local_data_source.dart';
import '../core/sync/sync_manager.dart';
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
      () => LegalRepositoryImpl(localDataSource: sl()),
    );
    // DataSources
    sl.registerLazySingleton<LegalRemoteDataSource>(
      () => LegalRemoteDataSourceImpl(supabaseClient: Supabase.instance.client),
    );
    // Local database (offline-first). Registered as a singleton so every screen
    // shares one SQLite connection.
    sl.registerLazySingleton<AppDatabase>(AppDatabase.new);
      sl.registerLazySingleton<LocalDataSource>(
        () => LocalDataSourceImpl(sl()),
      );
      sl.registerLazySingleton<ConnectivityService>(ConnectivityService.new);
      sl.registerLazySingleton<SyncManager>(
        () => SyncManager(
          db: sl(),
          supabase: Supabase.instance.client,
          connectivity: sl(),
        ),
      );
    }