import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_backend.dart';
import 'core/ads/ad_mob_service.dart';
import 'core/app_theme.dart';
import 'core/backend_environment_scope.dart';
import 'core/injection_container.dart';
import 'core/review_session_store.dart';
import 'core/sync/sync_types.dart';
import 'features/legal_cases/presentation/bloc/legal_cubit.dart';
import 'features/legal_cases/presentation/screens/categories_screen.dart';
import 'features/legal_cases/presentation/state/legal_case_favorites.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.initialize();
  await LegalCaseFavorites.instance.initialize();

  const reviewOnlyBuild = bool.fromEnvironment('REVIEW_BUILD');
  final reviewUrl = const String.fromEnvironment('REVIEW_SUPABASE_URL');
  final reviewKey = const String.fromEnvironment(
    'REVIEW_SUPABASE_PUBLISHABLE_KEY',
  );
  SupabaseClient? productionClient;
  SupabaseClient? reviewClient;

  if (reviewOnlyBuild) {
    final parsedReviewUrl = Uri.tryParse(reviewUrl);
    if (parsedReviewUrl == null ||
        parsedReviewUrl.scheme != 'https' ||
        parsedReviewUrl.host.isEmpty ||
        !isPublishableSupabaseKey(reviewKey)) {
      throw StateError(
        'Review builds require an HTTPS review URL and a public '
        'publishable/anon key. Production will not be used as a fallback.',
      );
    }

    final candidateClient = SupabaseClient(reviewUrl, reviewKey);
    try {
      final reviewStorage = SharedPreferencesLocalStorage(
        persistSessionKey: reviewSessionStorageKey,
      );
      await ReviewSessionStore(
        client: candidateClient,
        storage: reviewStorage,
      ).initialize();
      reviewClient = candidateClient;
    } catch (error, stackTrace) {
      await candidateClient.dispose();
      Error.throwWithStackTrace(error, stackTrace);
    }
  } else {
    await Supabase.initialize(
      url: 'https://ptsfjeersiesgjtvcjkh.supabase.co',
      anonKey: 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O',
    );
    productionClient = Supabase.instance.client;

    if (reviewUrl.isNotEmpty && reviewKey.isNotEmpty) {
      final parsedReviewUrl = Uri.tryParse(reviewUrl);
      if (parsedReviewUrl != null &&
          parsedReviewUrl.scheme == 'https' &&
          parsedReviewUrl.host.isNotEmpty &&
          isPublishableSupabaseKey(reviewKey)) {
        SupabaseClient? candidateClient;
        try {
          final reviewStorage = SharedPreferencesLocalStorage(
            persistSessionKey: reviewSessionStorageKey,
          );
          candidateClient = SupabaseClient(reviewUrl, reviewKey);
          await ReviewSessionStore(
            client: candidateClient,
            storage: reviewStorage,
          ).initialize();
          reviewClient = candidateClient;
        } catch (error, stackTrace) {
          await candidateClient?.dispose();
          debugPrint(
            'Optional review backend unavailable: $error\n$stackTrace',
          );
        }
      } else {
        debugPrint(
          'Optional review backend disabled: use an HTTPS project URL and a '
          'public publishable/anon key.',
        );
      }
    } else if (reviewUrl.isNotEmpty || reviewKey.isNotEmpty) {
      debugPrint(
        'Optional review backend disabled: set both review Supabase values.',
      );
    }
  }

  await initDependencies(
    productionClient: productionClient,
    reviewClient: reviewClient,
    reviewOnly: reviewOnlyBuild,
  );

  final backend = sl<AppBackendRegistry>();
  await backend.activate(backend.defaultEnvironment);
  unawaited(AdMobService.initialize());
  runApp(const MyApp());

  unawaited(
    backend.syncManager.sync().then((result) {
      if (result.status == SyncStatus.failure) {
        debugPrint('Background startup sync failed: ${result.error}');
      }
    }),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مِراس | تدريب المحامي',
      theme: AppColors.theme,
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: AppThemeController.isLight,
        builder: (context, _, _) => Theme(
          data: AppColors.theme,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: AppOpenAdStartupGate(
        child: BackendEnvironmentScope(
          backend: sl<AppBackendRegistry>(),
          builder: (_) => BlocProvider(
            create: (_) => sl<LegalCubit>(),
            child: const CategoriesScreen(),
          ),
        ),
      ),
    );
  }
}
