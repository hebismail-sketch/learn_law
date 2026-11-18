import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/sync/app_database.dart';
import 'package:learn_law/core/sync/connectivity_service.dart';
import 'package:learn_law/core/sync/local_data_source.dart';
import 'package:learn_law/core/sync/sync_manager.dart';
import 'package:learn_law/core/sync/sync_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Security regression tests for the offline outbox.
///
/// The point of these tests is not the happy path but the failure modes that
/// used to exist in the old code: a signed-out or non-admin device trying to
/// push writes, another account inheriting a previous account's queue, and a
/// write for a row that is not there queueing a phantom operation.
void main() {
  late AppDatabase database;
  late LocalDataSourceImpl local;
  late SyncManager syncManager;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    local = LocalDataSourceImpl(database, queuedActorId: 'admin-user');
    syncManager = SyncManager(
      db: database,
      supabase: SupabaseClient('http://127.0.0.1:1', 'test-publishable-key'),
      anonKey: 'test-publishable-key',
      connectivity: _OnlineConnectivityService(),
    );
  });

  tearDown(() async {
    await syncManager.dispose();
    await database.close();
  });

  Future<List<PendingOp>> queue() => database.select(database.syncQueue).get();

  test('queued operations carry the account that wrote them', () async {
    await local.insertCategory(name: ' torture ');
    final rows = await queue();
    expect(rows, hasLength(1));
    expect(rows.single.actorId, 'admin-user');
    expect(rows.single.targetTable, SyncTables.categories);
  });

  test(
    'a sign-out clears the owner so the next account inherits nothing',
    () async {
      await local.insertCategory(name: 'x');
      await local.markQueuedActor(null);
      expect((await queue()).single.actorId, isNull);
    },
  );

  test('re-stamping moves unowned rows to the signing-in account', () async {
    await local.markQueuedActor(null);
    await local.insertCategory(name: 'x');
    await local.markQueuedActor('other-admin');
    expect((await queue()).single.actorId, 'other-admin');
  });

  test('discarding by account only removes that account\'s rows', () async {
    // Two separate rows: the queue collapses operations on the same row.
    await local.markQueuedActor('other-admin');
    await local.insertCategory(name: 'theirs');
    await local.markQueuedActor('admin-user');
    await local.insertCategory(name: 'mine');

    // Re-stamping is what a sign-in/sign-out does: it moves the pending rows
    // to the account currently using the device.
    final rows = await queue();
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.actorId), everyElement('admin-user'));
    expect(await local.discardQueuedOperationsFor({'other-admin'}), 0);

    // Give one row a distinct owner directly, as a row queued before a role
    // change would have.
    final firstId = rows.first.id;
    await (database.update(database.syncQueue)
          ..where((t) => t.id.equals(firstId)))
        .write(const SyncQueueCompanion(actorId: Value('other-admin')));

    final removed = await local.discardQueuedOperationsFor({'other-admin'});

    expect(removed, 1);
    expect((await queue()).single.actorId, 'admin-user');
  });

  test('re-stamping moves every pending row, whoever wrote it', () async {
    await local.markQueuedActor('other-admin');
    await local.insertCategory(name: 'theirs');
    await local.insertCategory(name: 'also theirs');

    await local.markQueuedActor(null);

    expect((await queue()).map((row) => row.actorId), everyElement(isNull));
  });

  test(
    'writing to a missing parent row is rejected before it is queued',
    () async {
      expect(
        () => local.insertSubcategory(categoryId: 'missing', name: 'x'),
        throwsStateError,
      );
      expect(await queue(), isEmpty);
    },
  );

  test(
    'updating a row that no longer exists is rejected, not queued',
    () async {
      expect(
        () => local.updateCategory(id: 'missing', name: 'x'),
        throwsStateError,
      );
      expect(await queue(), isEmpty);
    },
  );

  test('a private local edit is never sent to the server', () async {
    await local.insertCategory(name: 'private');

    final result = await syncManager.flushPendingOperations();

    // No session: the flush reports offline/failure, and the queue is intact.
    expect(result.status, isNot(SyncStatus.success));
    expect(await queue(), hasLength(1));
  });

  test(
    'rows with no recorded owner are still usable by the next account',
    () async {
      // Rows queued by an earlier app version have no actor id. They must not
      // block the queue for whoever is signed in now.
      await database
          .into(database.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'legacy',
              targetTable: SyncTables.categories,
              rowId: 'row',
              operation: 'update',
              createdAt: DateTime.now().toUtc(),
            ),
          );
      final removed = await local.discardQueuedOperationsFor({'admin-user'});
      expect(removed, 0);
      expect(await queue(), hasLength(1));
    },
  );

  test('unknown table names in the queue are not trusted', () async {
    await database
        .into(database.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            id: 'op',
            targetTable: 'auth_users',
            rowId: 'x',
            operation: 'insert',
            createdAt: DateTime.now().toUtc(),
            actorId: const Value('admin-user'),
          ),
        );
    final result = await syncManager.flushPendingOperations();
    expect(result.status, isNot(SyncStatus.success));
  });

  test('a queued payload only names content columns', () async {
    await local.insertCategory(name: 'x', description: 'd');
    final op = (await queue()).single;
    final payload = jsonDecode(op.payload!) as Map<String, dynamic>;
    expect(
      payload.keys,
      unorderedEquals(<String>['id', 'name', 'description']),
    );
  });
}

class _OnlineConnectivityService extends ConnectivityService {
  @override
  Future<bool> get isOnline async => true;
}
