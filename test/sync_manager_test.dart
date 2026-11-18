import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/sync/app_database.dart';
import 'package:learn_law/core/sync/connectivity_service.dart';
import 'package:learn_law/core/sync/sync_manager.dart';
import 'package:learn_law/core/sync/sync_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late AppDatabase database;
  late SyncManager syncManager;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    syncManager = SyncManager(
      db: database,
      supabase: SupabaseClient('http://localhost:54321', 'test-key'),
      anonKey: 'test-key',
      connectivity: _FailingConnectivityService(),
    );
  });

  tearDown(() async {
    await syncManager.dispose();
    await database.close();
  });

  test('reports connectivity check errors as a failed sync', () async {
    final result = await syncManager.sync();

    expect(result.status, SyncStatus.failure);
    expect(result.error, contains('connectivity check failed'));
  });

  group('outbox and network', _outboxAndNetworkRules);
}

class _FailingConnectivityService extends ConnectivityService {
  @override
  Future<bool> get isOnline async {
    throw StateError('connectivity check failed');
  }
}

class _OnlineConnectivityService extends ConnectivityService {
  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();
}

/// Behaviour that keeps the reader's screens consistent with what the outbox
/// still owes the server.
void _outboxAndNetworkRules() {
  late AppDatabase database;
  late SyncManager syncManager;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    syncManager = SyncManager(
      db: database,
      // Unreachable on purpose: every assertion below is about what happens
      // *before* a request would be sent.
      supabase: SupabaseClient('http://127.0.0.1:1', 'test-publishable-key'),
      anonKey: 'test-publishable-key',
      connectivity: _OnlineConnectivityService(),
    );
  });

  tearDown(() async {
    await syncManager.dispose();
    await database.close();
  });

  test(
    'refreshing a case roadmap never throws when the server is unreachable',
    () async {
      // The roadmap screen shows the local steps first; a failed refresh used
      // to surface as "the roadmaps could not be updated" on an offline phone.
      expect(await syncManager.refreshCaseSteps('case-1'), 0);
    },
  );

  test('an empty outbox flushes as a success', () async {
    final result = await syncManager.flushPendingOperations();
    expect(result.status, SyncStatus.success);
  });
}
