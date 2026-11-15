import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_log.dart';
import '../legal_text.dart';
import 'admin_guard.dart';
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

class _PushQueueResult {
  const _PushQueueResult({required this.pushed, this.skipped = 0, this.error});

  final int pushed;

  /// Entries the server deliberately refused (as opposed to could not be
  /// reached). They stay queued, but they do not stop the rest of the queue
  /// or the pull, so one bad row cannot freeze the device forever.
  final int skipped;

  /// Set only for problems that affect every entry, such as no network or no
  /// signed-in session. Presenting those as per-row failures would inflate
  /// the attempt counter of rows that were never actually sent.
  final Object? error;
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
///
/// Reads are anonymous (`anon`) and writes need the editor's own session and
/// the `app_metadata.role=admin` claim the RLS policies check. The app never
/// decides by itself what may be written; it only decides whether asking is
/// worth a network round trip.
class SyncManager {
  static const _caseStepsBackfillMarker = '__case_steps_backfill_v1__';
  static const _pullPageSize = 500;

  final AppDatabase db;
  final SupabaseClient supabase;
  final ConnectivityService connectivity;

  /// Reads while nobody is signed in.
  ///
  /// A Supabase client sends whatever session it holds. Without an account
  /// that is the publishable key alone, which RLS treats as `anon` — the same
  /// policy path the app has always used for content. Going through an
  /// explicit client (instead of relying on the absence of a session) means
  /// the reading path keeps working even if a session is restored later.
  late final SupabaseClient _anonymous;

  final _controller = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _controller.stream;

  /// Guards against overlapping runs when several triggers fire at once.
  Future<SyncResult>? _inFlight;

  SyncManager({
    required this.db,
    required this.supabase,
    required this.connectivity,
  }) {
    // Copy the endpoint and publishable key, not the session: this client
    // stays anonymous for its whole life.
    final headers = Map<String, String>.from(supabase.headers);
    _anonymous = SupabaseClient(
      supabase.rest.url.replaceFirst(RegExp(r'/rest/v1/?$'), ''),
      headers['apikey'] ?? '',
      headers: headers,
    );
  }

  /// The client to read with: anonymous unless an editor is signed in.
  SupabaseClient get _reader =>
      hasSignedInSession(supabase) ? supabase : _anonymous;

  /// Runs a sync, or joins the one already running.
  Future<SyncResult> sync() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  /// Pushes whatever is queued, without pulling.
  ///
  /// Used right before a sign-out: once the session ends the queued writes
  /// can no longer be authorized, so this is the last chance to hand them
  /// over. Failures are reported but never thrown: the queue stays on disk,
  /// and the caller's next account starts with a clean outbox anyway.
  Future<SyncResult> flushPendingOperations() async {
    try {
      final pending = await db.select(db.syncQueue).get();
      if (pending.isEmpty) return const SyncResult(status: SyncStatus.success);
      if (!await connectivity.isOnline) {
        return const SyncResult(status: SyncStatus.offline);
      }
      final push = await _pushQueue();
      return SyncResult(
        pushed: push.pushed,
        status: push.error == null ? SyncStatus.success : SyncStatus.failure,
        error: push.error?.toString(),
      );
    } catch (e) {
      logError('Flush before sign-out failed', e);
      return SyncResult(status: SyncStatus.failure, error: e.toString());
    }
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

    try {
      if (!await connectivity.isOnline) {
        _emit(SyncStatus.offline);
        return const SyncResult(status: SyncStatus.offline);
      }

      final push = await _pushQueue();
      // A queue that could not be flushed (no session, network dropped) still
      // leaves the pull worth running: reads are anonymous and keep the
      // offline copy current, and the pending writes stay safe on disk.
      final pulled = await _pullChanges();
      if (push.error != null) {
        _emit(SyncStatus.failure);
        return SyncResult(
          pushed: push.pushed,
          pulled: pulled,
          status: SyncStatus.failure,
          error: push.error.toString(),
        );
      }
      _emit(SyncStatus.success);
      return SyncResult(
        pushed: push.pushed,
        pulled: pulled,
        status: SyncStatus.success,
      );
    } catch (e) {
      _emit(SyncStatus.failure);
      logError('Sync failed', e);
      return SyncResult(status: SyncStatus.failure, error: e.toString());
    }
  }

  // ------------------------------- push -------------------------------

  /// Sends every queued operation and clears the ones the server accepted.
  ///
  /// Before anything is sent the current user must be an administrator by the
  /// same rule the RLS policies use. A signed-out phone therefore queues its
  /// offline edits without ever attempting a write, and a signed-in non-admin
  /// gets the same treatment instead of a stream of authorization errors.
  Future<_PushQueueResult> _pushQueue() async {
    final pending = await (db.select(
      db.syncQueue,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    if (pending.isEmpty) return const _PushQueueResult(pushed: 0);

    if (!hasSignedInSession(supabase)) {
      return const _PushQueueResult(
        pushed: 0,
        error: 'Pending changes wait for an administrator sign-in.',
      );
    }
    if (!await AdminGuard.verify(supabase)) {
      // A session that is valid but no longer carries the admin role cannot
      // push anything, and never will: an account's role is not something the
      // user can change, so these entries are dead weight. They are dropped
      // instead of retried forever. Anything queued before the role was lost
      // is discarded with them.
      await _discardDeadQueue();
      return const _PushQueueResult(
        pushed: 0,
        error: 'Pending changes were discarded: not an administrator.',
      );
    }

    final currentUserId = supabase.auth.currentUser?.id;
    // Rows queued before owners were recorded (older builds) have no actor
    // and are pushed by whoever is now verified as an admin.
    final ownedByOtherAccount = pending.any(
      (op) => op.actorId != null && op.actorId != currentUserId,
    );
    if (ownedByOtherAccount) {
      // Written by another account on this device. Pushing it now would move
      // one editor's unpublished content onto another editor's session.
      return const _PushQueueResult(
        pushed: 0,
        error: 'Pending changes belong to a different account.',
      );
    }

    var pushed = 0;
    var skipped = 0;
    for (final op in pending) {
      try {
        await _applyRemote(op);
        // Only clear the entry after the server confirmed the write, so a
        // crash mid-push replays the operation instead of losing it.
        await (db.delete(db.syncQueue)..where((t) => t.id.equals(op.id))).go();
        pushed++;
      } on PostgrestException catch (e) {
        // The server answered and refused: an RLS denial, a constraint or a
        // missing row. Retrying forever would block every later edit, so the
        // entry is set aside locally and the loop continues.
        await _recordFailure(op, e);
        skipped++;
        logError('Queued ${op.operation} on ${op.targetTable} was refused', e);
      } catch (e) {
        // Transport-level: nothing was decided, so stop and retry later.
        await _recordFailure(op, e);
        return _PushQueueResult(pushed: pushed, skipped: skipped, error: e);
      }
    }
    return _PushQueueResult(pushed: pushed, skipped: skipped);
  }

  Future<void> _applyRemote(PendingOp op) async {
    // The table name comes from the local outbox, which is user-writable on a
    // rooted phone. Only the four known tables may ever be targeted.
    if (!SyncTables.all.contains(op.targetTable)) {
      throw ArgumentError('Unknown sync table: ${op.targetTable}');
    }
    final table = supabase.from(op.targetTable);
    final payload = op.payload == null
        ? <String, dynamic>{}
        : jsonDecode(op.payload!) as Map<String, dynamic>;

    if (op.targetTable == SyncTables.legalCases) {
      if (payload['title'] is String) {
        payload['title'] = stripLegalTextSymbols(payload['title'] as String);
      }
      if (payload['description'] is String) {
        payload['description'] = stripLegalTextSymbols(
          payload['description'] as String,
        );
      }
    } else if (op.targetTable == SyncTables.caseSteps) {
      if (payload['title'] is String) {
        payload['title'] = stripLegalTextSymbols(payload['title'] as String);
      }
      if (payload['short_description'] is String) {
        payload['short_description'] = stripLegalTextSymbolsFromStepDescription(
          payload['short_description'] as String,
        );
      }
    }

    switch (op.operation) {
      case 'insert':
        // A plain insert, not an upsert: an upsert on `id` would let a changed
        // payload overwrite a row the policy only allows this user to update,
        // and it hides a genuine duplicate from the server audit trail.
        await table.insert(payload);
      case 'update':
        // The queue row already carries the id, so the update is keyed on it
        // rather than trusting a second copy inside the payload.
        final updated = await table
            .update(payload)
            .eq('id', op.rowId)
            .select('id');
        if (updated.isEmpty) {
          throw StateError(
            'Update was not authorized or the row no longer exists.',
          );
        }
      case 'delete':
        // Soft delete on the server so other devices learn about the removal
        // instead of the row simply vanishing for them.
        final updated = await table
            .update(<String, dynamic>{
              'deleted_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', op.rowId)
            .select('id');
        if (updated.isEmpty) {
          throw StateError(
            'Delete was not authorized or the row no longer exists.',
          );
        }
      default:
        throw ArgumentError('Unknown operation: ${op.operation}');
    }
  }

  Future<void> _recordFailure(PendingOp op, Object error) async {
    await (db.update(db.syncQueue)..where((t) => t.id.equals(op.id))).write(
      SyncQueueCompanion(
        attempts: Value(op.attempts + 1),
        // Stored for diagnostics only; read on this device, never uploaded.
        lastError: Value(_describe(error)),
      ),
    );
  }

  /// Drops operations that can never be authorized again.
  ///
  /// Called when the session is signed in but the server refuses writes to it
  /// because the account is no longer an administrator. Such entries would be
  /// rejected on every later sync, so keeping them only risks leaking content
  /// into whatever the next account on the device does.
  Future<void> _discardDeadQueue() async {
    final removed = await db.delete(db.syncQueue).go();
    if (removed == 0) return;
    logDebug(
      'Dropped $removed queued operation(s) not authorized for this account.',
    );
  }

  /// A short description of a failure that carries no request content.
  String _describe(Object error) {
    if (error is PostgrestException) {
      return '${error.code ?? 'error'}: ${error.message}';
    }
    return error.runtimeType.toString();
  }

  // ------------------------------- pull -------------------------------

  /// Fetches rows changed since the last successful sync into the local copy.
  Future<int> _pullChanges() async {
    var pulled = 0;
    await _ensureCaseStepsBackfill();

    // Parents first so a child never arrives before the row it points at.
    for (final table in SyncTables.all) {
      final since = await _lastSyncedAt(table);
      final pullStartedAt = DateTime.now().toUtc();
      var offset = 0;
      late List<dynamic> response;

      do {
        response = await _reader
            .from(table)
            .select()
            .gt('updated_at', since.toUtc().toIso8601String())
            .order('updated_at', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + _pullPageSize - 1);

        // Rows arrive including soft-deleted ones. That is deliberate: a
        // delete is how this device learns another device removed a row.
        // _mergeRemoteRow applies deleted_at, and repository reads filter it.
        for (final row in response.cast<Map<String, dynamic>>()) {
          await _mergeRemoteRow(table, row);
          pulled++;
        }
        offset += response.length;
      } while (response.length == _pullPageSize);

      // Keep a small overlap so rows written while this pull was in progress
      // are eligible for the next pull instead of falling behind the watermark.
      final nextWatermark = pullStartedAt.subtract(const Duration(seconds: 1));
      if (nextWatermark.isAfter(since)) {
        await _setLastSyncedAt(table, nextWatermark);
      }
    }
    return pulled;
  }

  /// Refreshes every step for a single case before its roadmap is displayed.
  ///
  /// The normal startup pull is paginated across all tables and may continue
  /// after the UI has opened. This focused pull makes sure a case opened during
  /// that initial sync does not appear to have missing steps. Offline users
  /// keep using the local copy.
  Future<int> refreshCaseSteps(String caseId) async {
    if (!await connectivity.isOnline) return 0;

    var pulled = 0;
    var offset = 0;
    late List<dynamic> response;

    do {
      response = await _reader
          .from(SyncTables.caseSteps)
          .select()
          .eq('case_id', caseId)
          .order('step_number', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + _pullPageSize - 1);

      for (final row in response.cast<Map<String, dynamic>>()) {
        await _mergeRemoteRow(SyncTables.caseSteps, row);
        pulled++;
      }
      offset += response.length;
    } while (response.length == _pullPageSize);

    return pulled;
  }

  /// Clears the old step watermark once so devices re-fetch rows omitted by
  /// the previous single-page pull.
  Future<void> _ensureCaseStepsBackfill() async {
    final marker =
        await (db.select(db.syncState)
              ..where((t) => t.targetTable.equals(_caseStepsBackfillMarker))
              ..limit(1))
            .getSingleOrNull();
    if (marker != null) return;

    await db.transaction(() async {
      final existingMarker =
          await (db.select(db.syncState)
                ..where((t) => t.targetTable.equals(_caseStepsBackfillMarker))
                ..limit(1))
              .getSingleOrNull();
      if (existingMarker != null) return;

      await (db.delete(
        db.syncState,
      )..where((t) => t.targetTable.equals(SyncTables.caseSteps))).go();
      await db
          .into(db.syncState)
          .insert(
            SyncStateCompanion.insert(
              targetTable: _caseStepsBackfillMarker,
              lastSyncedAt: DateTime.now().toUtc(),
            ),
          );
    });
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
        await db
            .into(db.categories)
            .insertOnConflictUpdate(
              CategoriesCompanion.insert(
                id: id,
                name: (row['name'] ?? '').toString(),
                description: Value(row['description']?.toString()),
                updatedAt: updatedAt,
                deletedAt: Value(deletedAt),
              ),
            );
      case SyncTables.subcategories:
        await db
            .into(db.subcategories)
            .insertOnConflictUpdate(
              SubcategoriesCompanion.insert(
                id: id,
                categoryId: (row['category_id'] ?? '').toString(),
                name: (row['name'] ?? '').toString(),
                updatedAt: updatedAt,
                deletedAt: Value(deletedAt),
              ),
            );
      case SyncTables.legalCases:
        await db
            .into(db.legalCases)
            .insertOnConflictUpdate(
              LegalCasesCompanion.insert(
                id: id,
                subcategoryId: (row['subcategory_id'] ?? '').toString(),
                title: stripLegalTextSymbols(
                  (row['title'] ?? row['name'] ?? '').toString(),
                ),
                description: Value(
                  row['description'] == null
                      ? null
                      : stripLegalTextSymbols(row['description'].toString()),
                ),
                updatedAt: updatedAt,
                deletedAt: Value(deletedAt),
              ),
            );
      case SyncTables.caseSteps:
        await db
            .into(db.caseSteps)
            .insertOnConflictUpdate(
              CaseStepsCompanion.insert(
                id: id,
                caseId: (row['case_id'] ?? '').toString(),
                stepNumber: (row['step_number'] as num?)?.toInt() ?? 0,
                title: stripLegalTextSymbols((row['title'] ?? '').toString()),
                shortDescription: stripLegalTextSymbolsFromStepDescription(
                  (row['short_description'] ?? '').toString(),
                ),
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
        return query(
          db.select(db.subcategories)..where((t) => t.id.equals(id)),
        );
      case SyncTables.legalCases:
        return query(db.select(db.legalCases)..where((t) => t.id.equals(id)));
      case SyncTables.caseSteps:
        return query(db.select(db.caseSteps)..where((t) => t.id.equals(id)));
      default:
        throw ArgumentError('Unknown table: $table');
    }
  }

  Future<bool> _hasPending(String table, String id) async {
    final row =
        await (db.select(db.syncQueue)
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
    final row =
        await (db.select(db.syncState)
              ..where((t) => t.targetTable.equals(table))
              ..limit(1))
            .getSingleOrNull();
    return row?.lastSyncedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Future<void> _setLastSyncedAt(String table, DateTime at) async {
    await db
        .into(db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(targetTable: table, lastSyncedAt: at),
        );
  }

  void _emit(SyncStatus status) {
    if (!_controller.isClosed) {
      _controller.add(status);
    }
  }

  Future<void> dispose() async {
    await _anonymous.dispose();
    await _controller.close();
  }
}
