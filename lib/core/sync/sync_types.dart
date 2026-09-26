/// Shared vocabulary for the offline-first sync engine.
///
/// Everything in `lib/core/sync/` speaks these types so the local database,
/// the connectivity watcher and the sync manager stay decoupled.
library;

/// Lifecycle of a single sync attempt, surfaced to the UI via a stream.
enum SyncStatus {
  /// No sync has run yet in this session.
  idle,

  /// A sync is currently running.
  syncing,

  /// Last sync finished and both sides agree.
  success,

  /// Last sync failed; the queue is untouched and will be retried later.
  failure,

  /// Device has no usable network connection.
  offline,
}

/// The kind of mutation a queued entry represents.
enum SyncOperation {
  insert,
  update,
  delete,
}

/// Maps a Drift table name to the Supabase table it mirrors.
///
/// Kept as a single source of truth so the sync manager never hard-codes a
/// table string in more than one place.
class SyncTables {
  const SyncTables._();

  static const categories = 'categories';
  static const subcategories = 'subcategories';
  static const legalCases = 'legal_cases';
  static const caseSteps = 'case_steps';

  /// Every mirrored table, in dependency order (parents before children).
  static const all = <String>[
    categories,
    subcategories,
    legalCases,
    caseSteps,
  ];
}
