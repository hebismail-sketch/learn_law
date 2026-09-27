import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_database.dart';
import 'connectivity_service.dart';
import 'sync_types.dart';

/// Result of a single sync run.
class SyncResult {
  final int pushed;
  final int pulled;
  final SyncStatus status;
  final String? error;

  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    required this.status,
    this.error,
  });
}

/// Moves data between the local database and Supabase.
///
/// The order matters: pending local writes are pushed first so that the pull
/// that follows sees the rows this device just created and does not mistake
/// them for server-side deletions.
///
/// Rows are reconciled on `updated_at`. A local row is overwritten only when
/// the server copy is strictly newer *and* nothing is pending for that row, so
/// an unsynced local edit is never clobbered by a stale read.
class SyncManager {
  final AppDatabase db;
  final SupabaseClient supabase;
  final ConnectivityService connectivity;

  final _controller = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _controller.stream;

  /// Guards against overlapping runs when several triggers fire at once.
  Future<SyncResult>? _inFlight;

  SyncManager({
    required this.db,
    required this.supabase,
    required this.connectivity,
  });

  /// Runs a sync, or joins the one already running.
  Future<SyncResult> sync() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  /// Subscribes to connectivity changes and syncs whenever the network returns.
  StreamSubscription<bool> listenToConnectivity() {
    return connectivity.onStatusChange.listen((online) {
      if (online) {
        unawaited(sync());
      }
    });
  }

  Future<SyncResult> _run() async {
    _emit(SyncStatus.syncing);

    if (!await connectivity.isOnline) {
      _emit(SyncStatus.offline);
      return const SyncResult(status: SyncStatus.offline);
    }

    try {
      final pushed = await _pushQueue();
      final pulled = await _pullChanges();
      _emit(SyncStatus.success);
      return SyncResult(pushed: pushed, pulled: pulled, status: SyncStatus.success);
    } catch (e) {
      _emit(SyncStatus.failure);
      return SyncResult(status: SyncStatus.failure, error: e.toString());
    }
  }

  // ------------------------------- push -------------------------------

  /// Sends every queued operation and clears the ones the server accepted.
  Future<int> _pushQueue() async {
    final pending = await (db.select(db.syncQueue)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    var pushed = 0;
    for (final op in pending) {
      try {
        await _applyRemote(op);
        // Only clear the entry after the server confirmed the write, so a
        // crash mid-push replays the operation instead of losing it.
        await (db.delete(db.syncQueue)..where((t) => t.id.equals(op.id))).go();
        pushed++;
      } catch (e) {
        await _recordFailure(op, e);
        break; // preserve ordering: a later op may depend on this one
      }
    }
    return pushed;
  }

  Future<void> _applyRemote(PendingOp op) async {
    final table = supabase.from(op.targetTable);
    final payload =
        op.payload == null ? <String, dynamic>{} : jsonDecode(op.payload!) as Map<String, dynamic>;

    switch (op.operation) {
      case 'insert':
        await table.upsert(payload);
      case 'update':
        // The queue row already carries the id, so the update is keyed on it
        // rather than trusting a second copy inside the payload.
        await table.update(payload).eq('id', op.rowId);
      case 'delete':
        // Soft delete on the server so other devices learn about the removal
        // instead of the row simply vanishing for them.
        await table.update(<String, dynamic>{
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', op.rowId);
      default:
        throw ArgumentError('Unknown operation: ${op.operation}');
    }
  }

  Future<void> _recordFailure(PendingOp op, Object error) async {
    await (db.update(db.syncQueue)..where((t) => t.id.equals(op.id))).write(
      SyncQueueCompanion(
        attempts: Value(op.attempts + 1),
        lastError: Value(error.toString()),
      ),
    );
  }

  // ------------------------------- pull -------------------------------

  /// Fetches rows changed since the last successful sync into the local copy.
  Future<int> _pullChanges() async {
    var pulled = 0;
    // Parents first so a child never arrives before the row it points at.
    for (final table in SyncTables.all) {
      final since = await _lastSyncedAt(table);
      final response = await supabase
          .from(table)
          .select()
          .gt('updated_at', since.toUtc().toIso8601String())
          .order('updated_at', ascending: true);

      // Rows arrive including soft-deleted ones. That is deliberate: a delete
      // is how this device learns that a row another device removed is gone.
      // _mergeRemoteRow applies deleted_at, and the repository filters it out
      // of the UI reads.
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        await _mergeRemoteRow(table, row);
        pulled++;
      }
      await _setLastSyncedAt(table, DateTime.now().toUtc());
    }
    return pulled;
  }

  Future<void> _mergeRemoteRow(String table, Map<String, dynamic> row) async {
    final remoteUpdatedAt = _parseTimestamp(row['updated_at']);
    if (remoteUpdatedAt == null) return;

    final id = (row['id'] ?? '').toString();
    if (id.isEmpty) return;

    final localUpdatedAt = await _readLocalUpdatedAt(table, id);
    final hasPending = await _hasPending(table, id);

    // A local row with queued work wins: it holds edits the server has not
    // seen, and a pull that predates them would undo the user's change.
    if (localUpdatedAt != null && hasPending) return;

    // Otherwise the newest timestamp wins, with the server breaking ties.
    if (localUpdatedAt != null && !remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return;
    }

    await _writeLocal(table, row, remoteUpdatedAt);
  }

  Future<void> _writeLocal(
    String table,
    Map<String, dynamic> row,
    DateTime updatedAt,
  ) async {
    final id = row['id'].toString();
    final deletedAt = _parseTimestamp(row['deleted_at']);

    switch (table) {
      case SyncTables.categories:
        await db.into(db.categories).insertOnConflictUpdate(
              CategoriesCompanion.insert(
                id: id,
                name: (row['name'] ?? '').toString(),
                description: Value(row['description']?.toString()),
                updatedAt: updatedAt,
                deletedAt: Value(deletedAt),
              ),
            );
      case SyncTables.subcategories:
        await db.into(db.subcategories).insertOnConflictUpdate(
              SubcategoriesCompanion.insert(
                id: id,
                categoryId: (row['category_id'] ?? '').toString(),
                name: (row['name'] ?? '').toString(),
                updatedAt: updatedAt,
                deletedAt: Value(deletedAt),
              ),
            );
      case SyncTables.legalCases:
        await db.into(db.legalCases).insertOnConflictUpdate(
              LegalCasesCompanion.insert(
                id: id,
                subcategoryId: (row['subcategory_id'] ?? '').toString(),
                title: (row['title'] ?? row['name'] ?? '').toString(),
                description: Value(row['description']?.toString()),
                updatedAt: updatedAt,
                deletedAt: Value(deletedAt),
              ),
            );
      case SyncTables.caseSteps:
        await db.into(db.caseSteps).insertOnConflictUpdate(
              CaseStepsCompanion.insert(
                id: id,
                caseId: (row['case_id'] ?? '').toString(),
                stepNumber: (row['step_number'] as num?)?.toInt() ?? 0,
                title: (row['title'] ?? '').toString(),
                shortDescription: (row['short_description'] ?? '').toString(),
                updatedAt: updatedAt,
                deletedAt: Value(deletedAt),
              ),
            );
      default:
        throw ArgumentError('Unknown table: $table');
    }
  }

  /// Returns the local `updated_at` for [id], or null when the row is unknown.
  ///
  /// Only the timestamp is needed to decide whether the server copy wins, so
  /// this avoids threading four different row types into a shared signature.
  Future<DateTime?> _readLocalUpdatedAt(String table, String id) async {
    Future<DateTime?> query<T>(Selectable<T> selectable) async {
      final row = await selectable.getSingleOrNull();
      if (row == null) return null;
      return (row as dynamic).updatedAt as DateTime;
    }

    switch (table) {
      case SyncTables.categories:
        return query(db.select(db.categories)..where((t) => t.id.equals(id)));
      case SyncTables.subcategories:
        return query(db.select(db.subcategories)..where((t) => t.id.equals(id)));
      case SyncTables.legalCases:
        return query(db.select(db.legalCases)..where((t) => t.id.equals(id)));
      case SyncTables.caseSteps:
        return query(db.select(db.caseSteps)..where((t) => t.id.equals(id)));
      default:
        throw ArgumentError('Unknown table: $table');
    }
  }

  Future<bool> _hasPending(String table, String id) async {
    final row = await (db.select(db.syncQueue)
          ..where((t) => t.targetTable.equals(table) & t.rowId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  // --------------------------- bookkeeping ---------------------------

  DateTime? _parseTimestamp(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// Per-table watermark of the last successful pull.
  Future<DateTime> _lastSyncedAt(String table) async {
    final row = await (db.select(db.syncState)
          ..where((t) => t.targetTable.equals(table))
          ..limit(1))
        .getSingleOrNull();
    return row?.lastSyncedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Future<void> _setLastSyncedAt(String table, DateTime at) async {
    await db.into(db.syncState).insertOnConflictUpdate(
          SyncStateCompanion.insert(targetTable: table, lastSyncedAt: at),
        );
  }

  void _emit(SyncStatus status) {
    if (!_controller.isClosed) {
      _controller.add(status);
    }
  }

  Future<void> dispose() => _controller.close();
}
