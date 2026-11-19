import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_backend.dart';
import 'core/ads/ad_mob_service.dart';
import 'core/app_theme.dart';
import 'core/app_ui_scale.dart';
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

  // A release build must never stay on the splash screen. Anything that used
  // to run before the navigator — including the first-run download below — is
  // guarded, and whatever escapes is reported instead of leaving the user with
  // a window that never fills in.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('Uncaught error: $error\n$stackTrace');
    return true;
  };

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
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://ptsfjeersiesgjtvcjkh.supabase.co',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O',
    );
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
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
    anonKey: reviewOnlyBuild
        ? reviewKey
        : const String.fromEnvironment(
            'SUPABASE_ANON_KEY',
            defaultValue: 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O',
          ),
  );

  final backend = sl<AppBackendRegistry>();
  await backend.activate(backend.defaultEnvironment);

  // Fill the phone before the first screen is built.
  //
  // The first launch has to arrive with the whole library on disk, otherwise
  // the reader opens an empty app. This runs here, ahead of runApp, so no
  // widget — and no ad — is involved in the download: the app-open ad below
  // behaves exactly as it always has. Content already on the device (an update,
  // or any launch that is not the first) skips this entirely.
  //
  // The download is capped in time on purpose. The library is ~21k rows, which
  // costs ~35s on a fast link (test/download_timing_test.dart) and can cost
  // several minutes on a phone. Waiting for all of it here is what made a new
  // install look frozen on the Android splash screen, and Play's pre-launch
  // report treats that as an app that does not start. After the cap the app
  // opens with whatever arrived; the download keeps running in the background
  // and the readers refresh on the sync event when it finishes.
  if (!await backend.syncManager.hasContentLocally()) {
    try {
      final result = await backend.syncManager.downloadAllContent().timeout(
        _firstRunDownloadWindow,
      );
      if (!result.succeeded) {
        debugPrint('First-run download did not finish: ${result.error}');
      }
    } on TimeoutException {
      debugPrint(
        'First-run download is still running; opening the app with the '
        'content already on the device (it continues in the background).',
      );
    } catch (error, stackTrace) {
      // Never block the first frame on a download failure: the home screen
      // offers a reload, and the background sync retries the rest.
      debugPrint('First-run download failed: $error\n$stackTrace');
    }
  }

  unawaited(AdMobService.initialize());
  runApp(const MyApp());

  unawaited(
    backend.syncManager.sync().then(
      (result) {
        if (result.status == SyncStatus.failure) {
          debugPrint('Background startup sync failed: ${result.error}');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Background startup sync failed: $error\n$stackTrace');
      },
    ),
  );
}

/// How long a fresh install waits for its library before the UI is shown.
///
/// Long enough for a normal connection to deliver the whole library, short
/// enough that a slow or dead link can never look like a frozen app.
const _firstRunDownloadWindow = Duration(seconds: 20);

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
          // Same visual size on every device: the whole UI scales up on
          // tablets instead of showing the phone layout spread thin.
          child: AppUiScale.applyScale(
            context: context,
            child: child ?? const SizedBox.shrink(),
          ),
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
