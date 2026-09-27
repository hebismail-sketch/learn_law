import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'sync_types.dart';

part 'app_database.g.dart';

/// Every mirrored table carries these two columns.
///
/// `updatedAt` lets the sync manager pull incremental changes from Supabase
/// (`where updated_at > lastSyncedAt`). `deletedAt` implements soft deletes so
/// a device that was offline still learns that a row was removed.
class SyncColumns extends Table {
  /// Client-generated UUID. Generated on the phone so a row exists locally
  /// before it is ever pushed.
  ///
  /// This is the primary key, which is what lets the pull use
  /// `insertOnConflictUpdate` to upsert a server row onto an existing one.
  TextColumn get id => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};

  /// When this row was last modified on this device.
  DateTimeColumn get updatedAt => dateTime()();

  /// Non-null means the row is soft-deleted and hidden from all reads.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DataClassName('LocalCategory')
class Categories extends SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
}

@DataClassName('LocalSubcategory')
class Subcategories extends SyncColumns {
  TextColumn get categoryId => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
}

@DataClassName('LocalLegalCase')
class LegalCases extends SyncColumns {
  TextColumn get subcategoryId => text()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
}

@DataClassName('LocalCaseStep')
class CaseSteps extends SyncColumns {
  TextColumn get caseId => text()();
  IntColumn get stepNumber => integer()();
  TextColumn get title => text().withLength(min: 1, max: 255)();

  /// May embed `__BRANCHES_JSON__...` exactly as it does in Supabase, so the
  /// branch payload survives a round trip without a second column.
  TextColumn get shortDescription => text()();
}

/// Durable queue of local mutations waiting to be pushed to Supabase.
///
/// A row is removed from this table only after the server has acknowledged the
/// write, which is what makes the sync crash-safe.
@DataClassName('PendingOp')
class SyncQueue extends Table {
  /// Client-generated UUID used to coalesce repeated edits to the same row.
  TextColumn get id => text()();

  /// Supabase table name, one of [SyncTables.all].
  ///
  /// Named `targetTable` rather than `tableName` so it does not shadow
  /// Drift's own [Table.tableName] getter.
  TextColumn get targetTable => text()();

  /// Primary key of the affected row in that table.
  TextColumn get rowId => text()();

  /// One of `insert`, `update`, `delete`.
  TextColumn get operation => text()();

  /// The full row payload for insert/update, so a retry does not need to
  /// re-read the local row (which may have changed since).
  TextColumn get payload => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// Number of failed push attempts, used for backoff and error reporting.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();
}

/// Per-table watermark of the last successful pull.
///
/// Stored in its own table rather than inside [SyncQueue] so a watermark can
/// never be mistaken for a pending operation and pushed to the server.
@DataClassName('SyncWatermark')
class SyncState extends Table {
  /// One of [SyncTables.all]. The primary key, since there is one watermark
  /// row per table.
  TextColumn get targetTable => text()();
  @override
  Set<Column<Object>> get primaryKey => {targetTable};

  /// Timestamp of the newest row this device has already pulled.
  DateTimeColumn get lastSyncedAt => dateTime()();
}

@DriftDatabase(
  tables: [Categories, Subcategories, LegalCases, CaseSteps, SyncQueue, SyncState],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'learn_law'));

  /// Used by tests to run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // Required for the soft-delete `isNotNull` filters and for tables
          // that are mutated from the UI thread.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
