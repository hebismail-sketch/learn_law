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

  bool get succeeded => status == SyncStatus.success;
}

/// Progress of a full download, so the first-run screen can say what it is
/// doing instead of showing an indeterminate spinner for a minute.
class ContentDownloadProgress {
  const ContentDownloadProgress({
    required this.table,
    required this.downloaded,
    required this.isComplete,
  });

  /// Table being downloaded, one of [SyncTables.all] (or empty when done).
  final String table;
  final int downloaded;
  final bool isComplete;
}

/// Thrown when the reading key itself is missing.
///
/// A request without it comes back as "no API key" / "permission denied",
/// which the sync would otherwise report as a successful, empty download. That
/// is precisely how a phone ended up opened with no content, so this is a
/// failure the startup screen refuses to pass.
class _MissingReadKeyException implements Exception {
  const _MissingReadKeyException();

  @override
  String toString() => 'No publishable Supabase key is configured.';
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

  /// Bumped to v3 when the download stopped carrying soft-deleted rows: the
  /// marker name doubles as the "this build's rules completed" record, so a
  /// phone filled under v2 downloads again without the deleted content.
  static const _fullDownloadMarker = '__full_content_download_v3__';

  /// Rows per request.
  ///
  /// Exposed so the startup gate can estimate how many pages are left. Kept
  /// This is the server's own cap, measured (scripts/probe_page_cap.mjs): any
  /// `limit` above 1000 still returns exactly 1000 rows. A page bigger than
  /// this silently came back "short" and the walk stopped early with 2,066 of
  /// 20,778 rows — so it must never exceed 1000.
  ///
  /// 1000 (not 500) because a measured first run costs ~1.4s per page, almost
  /// all of it round-trip latency: 500 meant 39 requests for `case_steps`.
  static const pageSize = 1000;
  static const _pullPageSize = pageSize;

  final AppDatabase db;
  final SupabaseClient supabase;
  final ConnectivityService connectivity;

  final _controller = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _controller.stream;

  final _downloadProgress =
      StreamController<ContentDownloadProgress>.broadcast();
  Stream<ContentDownloadProgress> get downloadProgress =>
      _downloadProgress.stream;

  /// Guards against overlapping runs when several triggers fire at once.
  Future<SyncResult>? _inFlight;

  /// The publishable key this manager reads with.
  ///
  /// Null when the key cannot be found, in which case the reading client is
  /// not built at all: a client with an empty key answers 401 "No API key"
  /// for every request, which is indistinguishable from an empty library.
  final String? _publishableKey;

  /// Reads while nobody is signed in.
  ///
  /// A Supabase client sends whatever session it holds. Without an account
  /// that is the publishable key alone, which RLS treats as `anon` — the same
  /// policy path the app has always used for content. Going through an
  /// explicit client (instead of relying on the absence of a session) means
  /// the reading path keeps working even if a session is restored later. Null
  /// only when no key could be found, and then [_reader] refuses to read.
  late final SupabaseClient? _anonymous;

  /// [anonKey] is required: the key the anonymous reader signs every request
  /// with.
  ///
  /// The SDK keeps its own copy private (`_supabaseKey`), so it cannot be
  /// recovered from [supabase]. Reading with a missing key answers "no API
  /// key" for every request, which looks exactly like an empty library — that
  /// is how an install could open with no content.
  SyncManager({
    required this.db,
    required this.supabase,
    required this.connectivity,
    required String anonKey,
  }) : _publishableKey = _readPublishableKey(anonKey) {
    final key = _publishableKey;
    _anonymous = key == null
        ? null
        : SupabaseClient(_projectUrl(supabase), key);
  }

  /// Returns the key to read with, or null when [anonKey] is blank.
  ///
  /// Deliberately does not try to recover the key from [client]: the SDK keeps
  /// it private, and the earlier guesses produced a reader that answered "no
  /// API key" for every table — a download that "succeeded" with nothing.
  /// A blank key is now an error the caller sees, never an empty library.
  static String? _readPublishableKey(String? anonKey) {
    final key = anonKey?.trim();
    return key == null || key.isEmpty ? null : key;
  }

  /// The project URL behind [client], without the `/rest/v1` suffix.
  ///
  /// `client.rest` is a `RestClient`, which exposes the URL as a `Uri`, not a
  /// string; reading it any other way is what used to produce a wrong base
  /// address for the anonymous client.
  static String _projectUrl(SupabaseClient client) {
    final url = client.rest.url.toString();
    return url.replaceFirst(RegExp(r'/rest/v1/?$'), '');
  }

  /// The client to read with: anonymous unless an editor is signed in.
  SupabaseClient get _reader {
    if (hasSignedInSession(supabase)) return supabase;
    final anonymous = _anonymous;
    if (anonymous == null) {
      throw const _MissingReadKeyException();
    }
    return anonymous;
  }

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
      // When every table is already mirrored the first run downloaded all of
      // it, so a later sync with no transport is only an interrupted
      // incremental update, not a broken install.
      if (!await connectivity.isOnline) {
        final complete = await isContentReady();
        _emit(complete ? SyncStatus.success : SyncStatus.offline);
        return SyncResult(
          status: complete ? SyncStatus.success : SyncStatus.offline,
          error: complete ? null : 'offline',
        );
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

  /// True when every table has been fully downloaded at least once.
  ///
  /// Only this device knows the answer, so it survives restarts: the marker is
  /// written in the same transaction as the last table's watermark, which also
  /// means an interrupted first download is retried on the next launch instead
  /// of being remembered as finished.
  Future<bool> isContentReady() async {
    final marker =
        await (db.select(db.syncState)
              ..where((t) => t.targetTable.equals(_fullDownloadMarker))
              ..limit(1))
            .getSingleOrNull();
    return marker != null;
  }

  /// Downloads every row of every table, or as much is missing.
  ///
  /// This is what the first launch runs before the UI is shown: pages of
  /// [pageSize] until a short page, per-table watermarks updated as it goes, so
  /// a dropped connection resumes where it stopped. It walks tables in
  /// dependency order (categories → subcategories → legal cases → steps) so a
  /// case is never on screen without its roadmap.
  ///
  /// Anything that stops the walk halfway is a failure, never a success: the
  /// "complete" marker is only written after the last table finished.
  ///
  /// A single row the local schema refuses (a category whose name is blank is
  /// the one seen in production) is skipped and reported, not treated as a
  /// failed download: aborting on page one is how a phone stayed empty.
  ///
  /// [force] ignores the saved watermarks and walks every table from the
  /// start again, which is what a deliberate reload asks for: a row that was
  /// restored on the server keeps its old `updated_at` and would otherwise sit
  /// behind the watermark and never arrive.
  Future<SyncResult> downloadAllContent({
    bool force = false,
    void Function(ContentDownloadProgress progress)? onProgress,
  }) {
    final running = _downloadInFlight;
    if (running != null) {
      // A force request while the normal download runs is retried right after
      // it instead of being dropped.
      return force
          ? running.whenComplete(
              () => downloadAllContent(force: true, onProgress: onProgress),
            )
          : running;
    }
    return _downloadInFlight = _download(force, onProgress).whenComplete(() {
      _downloadInFlight = null;
    });
  }

  Future<SyncResult>? _downloadInFlight;

  Future<SyncResult> _download(
    bool force,
    void Function(ContentDownloadProgress progress)? onProgress,
  ) async {
    _emit(SyncStatus.syncing);
    var written = 0;
    final skipped = <String>[];

    try {
      if (_publishableKey == null) throw const _MissingReadKeyException();
      if (!await connectivity.isOnline) {
        _emit(SyncStatus.offline);
        return const SyncResult(status: SyncStatus.offline, error: 'offline');
      }

      // Only the live rows of every table ever reach the phone, so this also
      // sweeps out anything a previous build mirrored with a deleted marker.
      await _purgeSoftDeletedRows();

      for (final table in SyncTables.all) {
        written += await _downloadTable(
          table,
          force: force,
          onProgress: onProgress,
          skipped: skipped,
        );
      }

      // The marker and the watermarks are committed together, so "ready" can
      // never be true while a table is still missing its rows.
      await db
          .into(db.syncState)
          .insertOnConflictUpdate(
            SyncStateCompanion.insert(
              targetTable: _fullDownloadMarker,
              lastSyncedAt: DateTime.now().toUtc(),
            ),
          );

      // The walk starts before the server's writes land here; a row written in
      // that window has an `updated_at` newer than every watermark taken from
      // the downloaded rows and would wait for the next app start. The startup
      // sync that follows this download pulls them right away.
      unawaited(
        sync().then(
          (result) {
            if (result.status == SyncStatus.failure) {
              logDebug('Post-download pull failed: ${result.error}');
            }
          },
          onError: (Object error) =>
              logDebug('Post-download pull failed: $error'),
        ),
      );

      if (skipped.isNotEmpty) {
        logDebug(
          'Skipped ${skipped.length} server row(s) the local schema rejects: '
          '${skipped.join(', ')}',
        );
      }

      if (onProgress != null) {
        onProgress(
          ContentDownloadProgress(
            table: '',
            downloaded: written,
            isComplete: true,
          ),
        );
      }
      _emit(SyncStatus.success);
      return SyncResult(
        pulled: written,
        status: SyncStatus.success,
        error: written == 0 ? 'empty' : null,
      );
    } on _MissingReadKeyException {
      _emit(SyncStatus.failure);
      rethrow;
    } catch (e) {
      _emit(SyncStatus.failure);
      logError('Full content download failed', e);
      return SyncResult(
        pulled: written,
        status: SyncStatus.failure,
        error: e.toString(),
      );
    }
  }

  /// Downloads one table from its watermark to the last row.
  ///
  /// Pages are cut on the `updated_at` of the last row rather than on an
  /// offset: rows can be written while the walk is running, and a shifted
  /// offset silently skips them. The edge row is repeated on purpose, and
  /// `insertOnConflictUpdate` absorbs the duplicate.
  Future<int> _downloadTable(
    String table, {
    required bool force,
    void Function(ContentDownloadProgress progress)? onProgress,
    required List<String> skipped,
  }) async {
    // The download only ever writes live rows, so every table it fills must
    // start from the beginning on a first run; a leftover watermark from an
    // older build would otherwise leave the earlier rows missing.
    var since = force
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : await _watermarkOrStart(table);
    var written = 0;
    var downloaded = 0;

    while (true) {
      final pullStartedAt = DateTime.now().toUtc();
      // Only live rows are downloaded. Deleted content is never put on a phone:
      // the server marks a row with deleted_at the moment it is removed, so
      // filtering here keeps the local copy free of anything deleted, on first
      // run and on every later pull.
      //
      // Two pages requested at once measured slower than one at a time (each
      // pair cost more than two single pages: the server serialises the work
      // anyway), so the walk stays sequential. That also keeps the watermark a
      // description of a contiguous range that is fully on disk.
      final rows = await _fetchPage(table, since);

      // One write transaction per page instead of one per row: 1000 separate
      // statements inside a download frame is what made the walk cost seconds
      // per page. A refused row still cannot poison the page — each row keeps
      // its own try/catch.
      await db.transaction(() async {
        for (final row in rows) {
          try {
            await _mergeRemoteRow(table, row);
            written++;
          } catch (e) {
            // One row the local schema refuses must not cost the reader the
            // other 20,000: the walk moves on and the page edge still advances
            // below, so the download always makes progress.
            skipped.add('$table/${row['id'] ?? '?'} (${e.runtimeType})');
          }
          downloaded++;
        }
      });

      if (onProgress != null) {
        onProgress(
          ContentDownloadProgress(
            table: table,
            downloaded: downloaded,
            isComplete: false,
          ),
        );
      }

      if (rows.length < _pullPageSize) {
        // Last page: everything after `since` is stored. Keep a small overlap
        // so rows written while it was in flight are eligible for the next
        // pull instead of falling behind.
        await _setLastSyncedAt(
          table,
          pullStartedAt.subtract(const Duration(seconds: 1)),
        );
        return written;
      }

      // A full page: continue from its last row (repeated intentionally, and
      // absorbed by insertOnConflictUpdate).
      final nextSince = _parseTimestamp(rows.last['updated_at']);
      if (nextSince == null || !nextSince.isAfter(since)) {
        throw StateError('Content download made no progress on $table.');
      }
      since = nextSince;
      await _setLastSyncedAt(table, since);
    }
  }

  /// One page of live rows after [since].
  Future<List<Map<String, dynamic>>> _fetchPage(
    String table,
    DateTime since,
  ) async {
    final response = await _reader
        .from(table)
        .select()
        .gt('updated_at', since.toUtc().toIso8601String())
        .filter('deleted_at', 'is', null)
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .limit(_pullPageSize);
    return response.cast<Map<String, dynamic>>().toList();
  }

  /// Fetches rows changed since the last successful sync into the local copy.
  Future<int> _pullChanges() async {
    var pulled = 0;
    await _ensureCaseStepsBackfill();

    // Parents first so a child never arrives before the row it points at.
    //
    // Each table is pulled independently: a step row the local schema refuses
    // used to abort the whole pull (the walk and the per-row merge both throw),
    // which left every later table, and every later launch, permanent recipient
    // of the same failure. One bad row now costs only that row.
    for (final table in SyncTables.all) {
      try {
        pulled += await _pullTable(table);
      } catch (e) {
        logError('Pulling $table failed', e);
      }
    }
    return pulled;
  }

  /// One table, page by page, from its watermark to the newest row.
  Future<int> _pullTable(String table) async {
    var pulled = 0;
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

      for (final row in response.cast<Map<String, dynamic>>()) {
        try {
          await _mergeRemoteRow(table, row);
          pulled++;
        } catch (e) {
          logError('Skipping a ${row['id'] ?? '?'} row in $table', e);
        }
      }
      offset += response.length;
    } while (response.length == _pullPageSize);

    // Keep a small overlap so rows written while this pull was in progress
    // are eligible for the next pull instead of falling behind the watermark.
    final nextWatermark = pullStartedAt.subtract(const Duration(seconds: 1));
    if (nextWatermark.isAfter(since)) {
      await _setLastSyncedAt(table, nextWatermark);
    }
    return pulled;
  }

  /// Refreshes every step for a single case before its roadmap is displayed.
  ///
  /// The normal startup pull is paginated across all tables and may continue
  /// after the UI has opened. This focused pull makes sure a case opened during
  /// that initial sync does not appear to have missing steps. Offline users
  /// keep using the local copy.
  ///
  /// It never throws: the reader already sees the local steps, so a network
  /// failure here must not surface as "the roadmaps could not be updated" on a
  /// phone that simply lost its connection.
  Future<int> refreshCaseSteps(String caseId) async {
    try {
      return await _refreshCaseSteps(caseId);
    } catch (e) {
      logError('Refreshing the steps of a case failed', e);
      return 0;
    }
  }

  Future<int> _refreshCaseSteps(String caseId) async {
    if (!await connectivity.isOnline) return 0;

    var pulled = 0;
    var offset = 0;
    late List<dynamic> response;

    do {
      // Same rule as the full download: a row deleted on the server is never
      // written onto this phone, so a roadmap cannot show removed steps.
      response = await _reader
          .from(SyncTables.caseSteps)
          .select()
          .eq('case_id', caseId)
          .filter('deleted_at', 'is', null)
          .order('step_number', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + _pullPageSize - 1);

      final rows = response.cast<Map<String, dynamic>>().toList();
      for (final row in rows) {
        await _mergeRemoteRow(SyncTables.caseSteps, row);
        pulled++;
      }

      if (response.length < _pullPageSize) {
        // Server-side deletions no longer come down, so a step this case still
        // has locally but no longer has remotely is exactly a deleted one.
        // Marking it here keeps a previously downloaded step from lingering on
        // the phone after its roadmap was opened. Only checked on the last
        // page: that is the only point where the full list is known.
        final presentIds = {
          for (final row in rows) (row['id'] ?? '').toString(),
        };
        final now = DateTime.now().toUtc();
        final localSteps = await (db.select(
          db.caseSteps,
        )..where((t) => t.caseId.equals(caseId) & t.deletedAt.isNull())).get();
        for (final step in localSteps) {
          if (!presentIds.contains(step.id)) {
            await (db.update(
              db.caseSteps,
            )..where((t) => t.id.equals(step.id))).write(
              CaseStepsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
            );
          }
        }
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
    final queued = await _queuedOperation(table, id);

    // A delete that this device is still waiting to push must not be undone by
    // the server's copy of the row: the row is alive on the server until the
    // delete is pushed, so a pull would restore what the editor just removed
    // and the delete would then be "updating" a row the editor thinks is gone.
    if (queued == 'delete') return;

    // A local row with queued work wins: it holds edits the server has not
    // seen, and a pull that predates them would undo the user's change.
    if (localUpdatedAt != null && queued != null) return;

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

  /// The operation queued for [id] (`insert`, `update` or `delete`), or null
  /// when the row has no pending write.
  Future<String?> _queuedOperation(String table, String id) async {
    final row =
        await (db.select(db.syncQueue)
              ..where((t) => t.targetTable.equals(table) & t.rowId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    return row?.operation;
  }

  // --------------------------- bookkeeping ---------------------------

  DateTime? _parseTimestamp(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// The start of the first full download: epoch, unless this build has
  /// already finished one, in which case its per-table watermark is valid.
  Future<DateTime> _watermarkOrStart(String table) async {
    if (!await isContentReady()) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return _lastSyncedAt(table);
  }

  /// Removes anything already marked deleted from the phone.
  ///
  /// Deleted content is never delivered by this build, so a row carrying the
  /// marker can only be left over from an older one (or from a delete this
  /// device queued and already pushed). Clearing it here makes the promise
  /// literal: nothing deleted is stored on the device.
  Future<void> _purgeSoftDeletedRows() async {
    await db.transaction(() async {
      await (db.delete(
        db.caseSteps,
      )..where((t) => t.deletedAt.isNotNull())).go();
      await (db.delete(
        db.legalCases,
      )..where((t) => t.deletedAt.isNotNull())).go();
      await (db.delete(
        db.subcategories,
      )..where((t) => t.deletedAt.isNotNull())).go();
      await (db.delete(
        db.categories,
      )..where((t) => t.deletedAt.isNotNull())).go();
    });
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

  /// True when the phone holds enough content to show a usable home screen.
  ///
  /// Read straight from the tables, so it also covers installs that were
  /// filled before the full-download marker existed.
  Future<bool> hasContentLocally() async {
    if (await isContentReady()) return true;
    final category =
        await (db.select(db.categories)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (category == null) return false;
    final subcategory =
        await (db.select(db.subcategories)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (subcategory == null) return false;
    final legalCase =
        await (db.select(db.legalCases)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (legalCase == null) return false;
    final step =
        await (db.select(db.caseSteps)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    return step != null;
  }

  Future<void> dispose() async {
    await _anonymous?.dispose();
    await _controller.close();
    await _downloadProgress.close();
  }
}
