import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync/app_database.dart';
import 'sync/connectivity_service.dart';
import 'sync/local_data_source.dart';
import 'sync/sync_manager.dart';

enum AppBackendEnvironment { production, review }

/// Reads the role from the app metadata of the signed-in user.
///
/// `app_metadata` is server-managed, so the role cannot be set by the user.
Future<bool> hasAdminRole(User? user) async {
  if (user == null) return false;
  return user.appMetadata['role'] == 'admin';
}

/// Re-reads the user from the server that owns [client] and checks the role.
///
/// The refresh has to go through the same client as the session, so it must
/// never fall back to a global client instance.
Future<bool> verifyAdminRole(SupabaseClient client) async {
  final currentUser = client.auth.currentUser;
  if (currentUser == null) return false;
  final refreshed = await client.auth.getUser();
  return hasAdminRole(refreshed.user);
}

bool isPublishableSupabaseKey(String key) {
  if (key.startsWith('sb_publishable_')) return true;

  final parts = key.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map && payload['role'] == 'anon';
  } on FormatException {
    return false;
  }
}

class AdminAuthorizationException implements Exception {
  const AdminAuthorizationException();

  @override
  String toString() => 'This account does not have the admin role.';
}

class AppBackendContext {
  AppBackendContext({
    required this.client,
    required String databaseName,
    required ConnectivityService connectivity,
    required AppDatabase Function(String name) databaseFactory,
  }) : database = databaseFactory(databaseName) {
    localDataSource = LocalDataSourceImpl(database);
    syncManager = SyncManager(
      db: database,
      supabase: client,
      connectivity: connectivity,
    );
  }

  final SupabaseClient client;
  final AppDatabase database;
  late final LocalDataSource localDataSource;
  late final SyncManager syncManager;
}

class AppBackendRegistry {
  AppBackendRegistry({
    required SupabaseClient? productionClient,
    required SupabaseClient? reviewClient,
    bool reviewOnly = false,
    required ConnectivityService connectivity,
    AppDatabase Function(String name)? databaseFactory,
  }) : _reviewOnly = reviewOnly,
       _environment = ValueNotifier(
         reviewOnly
             ? AppBackendEnvironment.review
             : AppBackendEnvironment.production,
       ) {
    if (reviewOnly && reviewClient == null) {
      throw StateError(
        'A review-only build requires a review Supabase project.',
      );
    }
    if (!reviewOnly && productionClient == null) {
      throw StateError('A production Supabase project is required.');
    }

    final createDatabase = databaseFactory ?? (name) => AppDatabase(name: name);
    if (productionClient != null) {
      _contexts[AppBackendEnvironment.production] = AppBackendContext(
        client: productionClient,
        databaseName: 'learn_law',
        connectivity: connectivity,
        databaseFactory: createDatabase,
      );
    }
    if (reviewClient != null) {
      _contexts[AppBackendEnvironment.review] = AppBackendContext(
        client: reviewClient,
        databaseName: 'learn_law_review',
        connectivity: connectivity,
        databaseFactory: createDatabase,
      );
    }
  }

  final Map<AppBackendEnvironment, AppBackendContext> _contexts = {};
  final bool _reviewOnly;
  final ValueNotifier<AppBackendEnvironment> _environment;
  StreamSubscription<bool>? _connectivitySubscription;

  bool get reviewOnly => _reviewOnly;
  AppBackendEnvironment get defaultEnvironment => _reviewOnly
      ? AppBackendEnvironment.review
      : AppBackendEnvironment.production;
  AppBackendEnvironment get activeEnvironment => _environment.value;
  ValueListenable<AppBackendEnvironment> get environmentListenable =>
      _environment;
  bool get hasReviewBackend =>
      _contexts.containsKey(AppBackendEnvironment.review);

  AppBackendContext get active => _contextFor(activeEnvironment);
  SupabaseClient get client => active.client;
  LocalDataSource get localDataSource => active.localDataSource;
  AppDatabase get database => active.database;
  SyncManager get syncManager => active.syncManager;
  Future<bool> get currentUserIsAdmin => verifyAdminRole(client);

  AppBackendContext _contextFor(AppBackendEnvironment environment) {
    final context = _contexts[environment];
    if (context == null) {
      throw StateError('The review Supabase project is not configured.');
    }
    return context;
  }

  Future<void> activate(AppBackendEnvironment environment) async {
    if (_reviewOnly && environment != AppBackendEnvironment.review) {
      throw StateError('This build can only use the review environment.');
    }
    final next = _contextFor(environment);
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = next.syncManager.listenToConnectivity();
    if (_environment.value != environment) {
      _environment.value = environment;
    }
  }

  Future<void> signInAsAdmin({
    required AppBackendEnvironment environment,
    required String email,
    required String password,
  }) async {
    if (_reviewOnly && environment != AppBackendEnvironment.review) {
      throw StateError('This build can only use the review environment.');
    }
    final context = _contextFor(environment);
    await context.client.auth.signOut();
    await context.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (!await verifyAdminRole(context.client)) {
      await context.client.auth.signOut();
      throw const AdminAuthorizationException();
    }
    await activate(environment);
  }

  Future<void> signOutAndUseDefaultEnvironment() async {
    await active.client.auth.signOut();
    await activate(defaultEnvironment);
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _environment.dispose();
    for (final context in _contexts.values) {
      await context.syncManager.dispose();
      await context.database.close();
    }
  }
}
