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
}

class _FailingConnectivityService extends ConnectivityService {
  @override
  Future<bool> get isOnline async {
    throw StateError('connectivity check failed');
  }
}
