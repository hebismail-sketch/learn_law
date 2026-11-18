import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync/admin_guard.dart';
import 'sync/app_database.dart';
import 'sync/connectivity_service.dart';
import 'sync/local_data_source.dart';
import 'sync/sync_manager.dart';

enum AppBackendEnvironment { production, review }

/// Reads the role from the app metadata of the signed-in user.
///
/// `app_metadata` is server-managed, so the role cannot be set by the user.
/// This only inspects a [User] that Auth already returned; use
/// [verifyAdminRole] when the answer has to be current.
Future<bool> hasAdminRole(User? user) async {
  if (user == null) return false;
  return user.appMetadata['role'] == 'admin';
}

/// Re-reads the user from the server that owns [client] and checks the role.
///
/// The refresh has to go through the same client as the session, so it must
/// never fall back to a global client instance.
Future<bool> verifyAdminRole(SupabaseClient client) {
  return AdminGuard.verify(client);
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
    required String anonKey,
  }) : database = databaseFactory(databaseName) {
    localDataSource = LocalDataSourceImpl(
      database,
      queuedActorId: _signedInUserId(client),
    );
    // The key is handed over explicitly: the SDK keeps it private, and the
    // sync engine needs it to read content anonymously.
    syncManager = SyncManager(
      db: database,
      supabase: client,
      connectivity: connectivity,
      anonKey: anonKey,
    );
  }

  static String? _signedInUserId(SupabaseClient client) {
    try {
      return client.auth.currentUser?.id;
    } on AuthException {
      return null;
    }
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
    required String anonKey,
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
        anonKey: anonKey,
      );
    }
    if (reviewClient != null) {
      _contexts[AppBackendEnvironment.review] = AppBackendContext(
        client: reviewClient,
        databaseName: 'learn_law_review',
        connectivity: connectivity,
        databaseFactory: createDatabase,
        anonKey: anonKey,
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

  /// True when the active environment holds a real signed-in session.
  bool get hasSignedInSession =>
      AppBackendContext._signedInUserId(active.client) != null;

  AppBackendContext get active => _contextFor(activeEnvironment);
  SupabaseClient get client => active.client;
  LocalDataSource get localDataSource => active.localDataSource;
  AppDatabase get database => active.database;
  SyncManager get syncManager => active.syncManager;

  /// Server-checked admin answer. Writes and edit screens use this one.
  Future<bool> get currentUserIsAdmin => verifyAdminRole(client);

  /// The same question for UI decisions that must also work on a cold start
  /// without network. Falls back to the restored session's metadata only when
  /// the server cannot be reached.
  Future<bool> get adminAccessAllowed =>
      AdminGuard.verifyAllowingOffline(client);

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
    // From here on, anything this session queues carries its user id, so a
    // later sign-in by a different account cannot push it.
    await context.localDataSource.markQueuedActor(
      AppBackendContext._signedInUserId(context.client),
    );
    await activate(environment);
  }

  /// Ends the current session.
  ///
  /// The outbox is flushed while the session is still valid — writes that
  /// needed an admin are impossible after this point — and whatever is left
  /// loses its owner, so the next account on this device starts empty.
  Future<void> signOut() async {
    final context = active;
    await context.syncManager.flushPendingOperations();
    await context.localDataSource.markQueuedActor(null);
    await context.client.auth.signOut();
  }

  Future<void> signOutAndUseDefaultEnvironment() async {
    await signOut();
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
