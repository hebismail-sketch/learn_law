import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/app_backend.dart';
import 'package:learn_law/core/review_session_store.dart';
import 'package:learn_law/core/sync/app_database.dart';
import 'package:learn_law/core/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('only trusted app_metadata grants the admin role', () async {
    final admin = User.fromJson({
      'id': 'admin-user',
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': <String, dynamic>{'role': 'admin'},
      'user_metadata': <String, dynamic>{},
    });
    final userControlledRole = User.fromJson({
      'id': 'regular-user',
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{'role': 'admin'},
    });

    expect(await hasAdminRole(admin), isTrue);
    expect(await hasAdminRole(userControlledRole), isFalse);
    expect(await hasAdminRole(null), isFalse);
  });

  test('review configuration rejects service-role keys', () {
    String jwtWithRole(String role) {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'role': role})))
          .replaceAll('=', '');
      return 'header.$payload.signature';
    }

    expect(isPublishableSupabaseKey('sb_publishable_public-key'), isTrue);
    expect(isPublishableSupabaseKey(jwtWithRole('anon')), isTrue);
    expect(isPublishableSupabaseKey(jwtWithRole('service_role')), isFalse);
    expect(isPublishableSupabaseKey('not-a-public-key'), isFalse);
  });

  test(
    'review-only backend cannot activate the production environment',
    () async {
      final reviewClient = SupabaseClient(
        'https://review.example.co',
        'review-test-key',
      );
      final registry = AppBackendRegistry(
        productionClient: null,
        reviewClient: reviewClient,
        reviewOnly: true,
        connectivity: _OfflineConnectivityService(),
        databaseFactory: (_) => AppDatabase.forTesting(NativeDatabase.memory()),
      );

      expect(registry.defaultEnvironment, AppBackendEnvironment.review);
      expect(registry.activeEnvironment, AppBackendEnvironment.review);
      expect(
        () => registry.activate(AppBackendEnvironment.production),
        throwsStateError,
      );

      await registry.dispose();
      await reviewClient.dispose();
    },
  );

  test(
    'switching environments keeps local data and clients isolated',
    () async {
      final productionClient = SupabaseClient(
        'https://production.example.co',
        'production-test-key',
      );
      final reviewClient = SupabaseClient(
        'https://review.example.co',
        'review-test-key',
      );
      final registry = AppBackendRegistry(
        productionClient: productionClient,
        reviewClient: reviewClient,
        connectivity: _OfflineConnectivityService(),
        databaseFactory: (_) => AppDatabase.forTesting(NativeDatabase.memory()),
      );

      final productionDatabase = registry.database;
      final changes = <AppBackendEnvironment>[];
      registry.environmentListenable.addListener(
        () => changes.add(registry.activeEnvironment),
      );
      await registry.localDataSource.insertCategory(name: 'Production only');

      await registry.activate(AppBackendEnvironment.review);
      final reviewDatabase = registry.database;

      expect(registry.client, same(reviewClient));
      expect(reviewDatabase, isNot(same(productionDatabase)));
      expect(
        (await registry.localDataSource.getCategories()).map(
          (category) => category.name,
        ),
        isEmpty,
      );
      await registry.localDataSource.insertCategory(name: 'Review only');

      await registry.activate(AppBackendEnvironment.production);
      expect(registry.client, same(productionClient));
      expect(registry.database, same(productionDatabase));
      expect(
        (await registry.localDataSource.getCategories()).map(
          (category) => category.name,
        ),
        ['Production only'],
      );

      await registry.activate(AppBackendEnvironment.review);
      expect(registry.database, same(reviewDatabase));
      expect(
        (await registry.localDataSource.getCategories()).map(
          (category) => category.name,
        ),
        ['Review only'],
      );
      expect(changes, [
        AppBackendEnvironment.review,
        AppBackendEnvironment.production,
        AppBackendEnvironment.review,
      ]);

      await registry.dispose();
      await productionClient.dispose();
      await reviewClient.dispose();
    },
  );

  test(
    'clearing review session storage leaves production session storage intact',
    () async {
      SharedPreferences.setMockInitialValues({});
      final productionStorage = SharedPreferencesLocalStorage(
        persistSessionKey: 'sb-production-auth-token',
      );
      final reviewStorage = SharedPreferencesLocalStorage(
        persistSessionKey: reviewSessionStorageKey,
      );
      await productionStorage.initialize();
      await reviewStorage.initialize();

      await productionStorage.persistSession('production-session');
      await reviewStorage.persistSession('review-session');
      await reviewStorage.removePersistedSession();

      expect(await reviewStorage.accessToken(), isNull);
      expect(await productionStorage.accessToken(), 'production-session');
    },
  );
}

class _OfflineConnectivityService extends ConnectivityService {
  @override
  Future<bool> get isOnline async => false;

  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();
}
