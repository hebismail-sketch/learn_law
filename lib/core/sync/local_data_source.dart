import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'sync_types.dart';

/// Reads and writes the phone-side copy of the data. No network here.
///
/// The pattern for every write is always the same two steps, inside one
/// transaction so a crash can never leave them half-applied:
///   1. change the local row, so the user sees their edit immediately
///   2. append the same change to [SyncQueue], so it is pushed later
abstract class LocalDataSource {
  Future<List<LocalCategory>> getCategories();

  Future<String> insertCategory({
    required String name,
    String? description,
  });

  Future<void> updateCategory({
    required String id,
    required String name,
    String? description,
  });

  Future<void> deleteCategory({required String id});

  // --- subcategories ---

  Future<List<LocalSubcategory>> getSubcategories(String categoryId);

  Future<String> insertSubcategory({
    required String categoryId,
    required String name,
  });

  Future<void> updateSubcategory({
    required String id,
    required String name,
  });

  Future<void> deleteSubcategory({required String id});

  // --- legal_cases ---

  Future<List<LocalLegalCase>> getLegalCases(String subcategoryId);

  Future<String> insertLegalCase({
    required String subcategoryId,
    required String title,
    String? description,
  });

  Future<void> updateLegalCase({
    required String id,
    required String title,
    String? description,
  });

  Future<void> deleteLegalCase({required String id});

  // --- case_steps ---

  Future<List<LocalCaseStep>> getCaseSteps(String caseId);

  Future<String> insertCaseStep({
    required String caseId,
    required int stepNumber,
    required String title,
    required String shortDescription,
  });

  Future<void> updateCaseStep({
    required String id,
    int? stepNumber,
    String? title,
    String? shortDescription,
  });

  Future<void> deleteCaseStep({required String id});
}

class LocalDataSourceImpl implements LocalDataSource {
  final AppDatabase db;
  final _uuid = const Uuid();

  LocalDataSourceImpl(this.db);

  // ------------------------------ reads ------------------------------

  @override
  Future<List<LocalCategory>> getCategories() {
    return (db.select(db.categories)..where((t) => t.deletedAt.isNull())).get();
  }

  // ----------------------------- writes ------------------------------

  @override
  Future<String> insertCategory({
    required String name,
    String? description,
  }) async {
    final now = DateTime.now();

    // The id is minted here, not on the server, so the row is complete and
    // editable locally before it is ever pushed.
    final id = _uuid.v4();

    await db.transaction(() async {
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: id,
              name: name,
              description: Value(description),
              updatedAt: now,
            ),
          );

      await _enqueue(
        table: SyncTables.categories,
        rowId: id,
        operation: SyncOperation.insert.name,
        payload: <String, dynamic>{
          'id': id,
          'name': name,
          'description': description,
        },
        at: now,
      );
    });

    return id;
  }

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    String? description,
  }) async {
    final now = DateTime.now();

    await db.transaction(() async {
      // Only the columns we actually changed are listed. Anything omitted
      // stays exactly as it is, which is what keeps an edit from
      // accidentally clearing a field the caller never mentioned.
      //
      // That is why `description` is passed as Value.absent when the caller
      // left it out: an omitted argument must not mean "erase it".
      await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
            CategoriesCompanion(
              name: Value(name),
              description: Value.absentIfNull(description),
              updatedAt: Value(now),
            ),
          );

      await _enqueue(
        table: SyncTables.categories,
        rowId: id,
        operation: SyncOperation.update.name,
        // `id` is deliberately absent: the queue row already carries it in
        // rowId, and sending it twice invites a mismatch. `description` is
        // omitted for the same reason it was not written above.
        payload: <String, dynamic>{
          'name': name,
          'description': ?description,
        },
        at: now,
      );
    });
  }

  @override
  Future<void> deleteCategory({required String id}) async {
    final now = DateTime.now();

    await db.transaction(() async {
      // Soft delete: the row survives locally so the delete can be pushed
      // and so a later pull can confirm it.
      await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
            CategoriesCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _enqueue(
        table: SyncTables.categories,
        rowId: id,
        operation: SyncOperation.delete.name,
        payload: null,
        at: now,
      );
    });
  }

  // -------------------------- subcategories --------------------------

  @override
  Future<List<LocalSubcategory>> getSubcategories(String categoryId) {
    return (db.select(db.subcategories)
          ..where(
            (t) =>
                t.categoryId.equals(categoryId) & t.deletedAt.isNull(),
          ))
        .get();
  }

  @override
  Future<String> insertSubcategory({
    required String categoryId,
    required String name,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    await db.transaction(() async {
      await db.into(db.subcategories).insert(
            SubcategoriesCompanion.insert(
              id: id,
              categoryId: categoryId,
              name: name,
              updatedAt: now,
            ),
          );

      await _enqueue(
        table: SyncTables.subcategories,
        rowId: id,
        operation: SyncOperation.insert.name,
        payload: <String, dynamic>{
          'id': id,
          'category_id': categoryId,
          'name': name,
        },
        at: now,
      );
    });

    return id;
  }

  @override
  Future<void> updateSubcategory({
    required String id,
    required String name,
  }) async {
    final now = DateTime.now();

    await db.transaction(() async {
      await (db.update(db.subcategories)..where((t) => t.id.equals(id))).write(
            SubcategoriesCompanion(
              name: Value(name),
              updatedAt: Value(now),
            ),
          );

      await _enqueue(
        table: SyncTables.subcategories,
        rowId: id,
        operation: SyncOperation.update.name,
        payload: <String, dynamic>{'name': name},
        at: now,
      );
    });
  }

  @override
  Future<void> deleteSubcategory({required String id}) async {
    final now = DateTime.now();

    await db.transaction(() async {
      // A soft delete on a parent would leave its children visible on other
      // devices, so the whole subtree is marked in one go. The rows stay put
      // locally and the individual queue entries keep the server in step.
      await _softDeleteTree(
        table: SyncTables.subcategories,
        rowId: id,
        at: now,
        childTable: SyncTables.legalCases,
        childColumn: 'subcategory_id',
        grandChild: (caseId) => _softDeleteStepsFor(caseId, now),
      );
    });
  }

  // --------------------------- legal_cases ---------------------------

  @override
  Future<List<LocalLegalCase>> getLegalCases(String subcategoryId) {
    return (db.select(db.legalCases)
          ..where(
            (t) =>
                t.subcategoryId.equals(subcategoryId) & t.deletedAt.isNull(),
          ))
        .get();
  }

  @override
  Future<String> insertLegalCase({
    required String subcategoryId,
    required String title,
    String? description,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    await db.transaction(() async {
      await db.into(db.legalCases).insert(
            LegalCasesCompanion.insert(
              id: id,
              subcategoryId: subcategoryId,
              title: title,
              description: Value(description),
              updatedAt: now,
            ),
          );

      await _enqueue(
        table: SyncTables.legalCases,
        rowId: id,
        operation: SyncOperation.insert.name,
        payload: <String, dynamic>{
          'id': id,
          'subcategory_id': subcategoryId,
          'title': title,
          'description': description,
        },
        at: now,
      );
    });

    return id;
  }

  @override
  Future<void> updateLegalCase({
    required String id,
    required String title,
    String? description,
  }) async {
    final now = DateTime.now();

    await db.transaction(() async {
      await (db.update(db.legalCases)..where((t) => t.id.equals(id))).write(
            LegalCasesCompanion(
              title: Value(title),
              description: Value.absentIfNull(description),
              updatedAt: Value(now),
            ),
          );

      await _enqueue(
        table: SyncTables.legalCases,
        rowId: id,
        operation: SyncOperation.update.name,
        payload: <String, dynamic>{
          'title': title,
          'description': ?description,
        },
        at: now,
      );
    });
  }

  @override
  Future<void> deleteLegalCase({required String id}) async {
    final now = DateTime.now();

    await db.transaction(() async {
      await _softDeleteTree(
        table: SyncTables.legalCases,
        rowId: id,
        at: now,
        childTable: SyncTables.caseSteps,
        childColumn: 'case_id',
        grandChild: null,
      );
    });
  }

  // ---------------------------- case_steps ---------------------------

  @override
  Future<List<LocalCaseStep>> getCaseSteps(String caseId) {
    return (db.select(db.caseSteps)
          ..where((t) => t.caseId.equals(caseId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.stepNumber)]))
        .get();
  }

  @override
  Future<String> insertCaseStep({
    required String caseId,
    required int stepNumber,
    required String title,
    required String shortDescription,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    await db.transaction(() async {
      await db.into(db.caseSteps).insert(
            CaseStepsCompanion.insert(
              id: id,
              caseId: caseId,
              stepNumber: stepNumber,
              title: title,
              shortDescription: shortDescription,
              updatedAt: now,
            ),
          );

      await _enqueue(
        table: SyncTables.caseSteps,
        rowId: id,
        operation: SyncOperation.insert.name,
        payload: <String, dynamic>{
          'id': id,
          'case_id': caseId,
          'step_number': stepNumber,
          'title': title,
          'short_description': shortDescription,
        },
        at: now,
      );
    });

    return id;
  }

  @override
  Future<void> updateCaseStep({
    required String id,
    int? stepNumber,
    String? title,
    String? shortDescription,
  }) async {
    final now = DateTime.now();

    await db.transaction(() async {
      // Every argument is optional here because the roadmap editor renumbers
      // steps wholesale: a reorder touches step_number on many rows while
      // leaving title and short_description alone.
      await (db.update(db.caseSteps)..where((t) => t.id.equals(id))).write(
            CaseStepsCompanion(
              stepNumber: Value.absentIfNull(stepNumber),
              title: Value.absentIfNull(title),
              shortDescription: Value.absentIfNull(shortDescription),
              updatedAt: Value(now),
            ),
          );

      await _enqueue(
        table: SyncTables.caseSteps,
        rowId: id,
        operation: SyncOperation.update.name,
        payload: <String, dynamic>{
          'step_number': ?stepNumber,
          'title': ?title,
          'short_description': ?shortDescription,
        },
        at: now,
      );
    });
  }

  @override
  Future<void> deleteCaseStep({required String id}) async {
    final now = DateTime.now();

    await db.transaction(() async {
      await (db.update(db.caseSteps)..where((t) => t.id.equals(id))).write(
            CaseStepsCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _enqueue(
        table: SyncTables.caseSteps,
        rowId: id,
        operation: SyncOperation.delete.name,
        payload: null,
        at: now,
      );
    });
  }

  // ----------------------------- helpers -----------------------------

  /// Soft-deletes a row together with everything hanging off it.
  ///
  /// The child column is passed as a string because the three levels differ
  /// (`category_id` / `subcategory_id` / `case_id`) and a callback cannot
  /// express a dynamic column name. [grandChild] exists because deleting a
  /// subcategory reaches cases, and each of those has steps of its own.
  Future<void> _softDeleteTree({
    required String table,
    required String rowId,
    required DateTime at,
    required String childTable,
    required String childColumn,
    required Future<void> Function(String rowId)? grandChild,
  }) async {
    await _softDeleteOne(table: table, rowId: rowId, at: at);

    final children = await _readIds(childTable, childColumn, rowId);
    for (final childId in children) {
      await _softDeleteOne(table: childTable, rowId: childId, at: at);
      if (grandChild != null) {
        await grandChild(childId);
      }
    }
  }

  /// Marks every step belonging to [caseId] as deleted.
  Future<void> _softDeleteStepsFor(String caseId, DateTime at) async {
    final steps = await (db.select(db.caseSteps)
          ..where((t) => t.caseId.equals(caseId) & t.deletedAt.isNull()))
        .get();
    for (final step in steps) {
      await _softDeleteOne(
        table: SyncTables.caseSteps,
        rowId: step.id,
        at: at,
      );
    }
  }

  Future<void> _softDeleteOne({
    required String table,
    required String rowId,
    required DateTime at,
  }) async {
    // Flipping deleted_at and queueing the delete are one unit of work, so
    // this is called from inside a transaction by every caller.
    switch (table) {
      case SyncTables.categories:
        await (db.update(db.categories)..where((t) => t.id.equals(rowId))).write(
              CategoriesCompanion(
                deletedAt: Value(at),
                updatedAt: Value(at),
              ),
            );
      case SyncTables.subcategories:
        await (db.update(db.subcategories)..where((t) => t.id.equals(rowId))).write(
              SubcategoriesCompanion(
                deletedAt: Value(at),
                updatedAt: Value(at),
              ),
            );
      case SyncTables.legalCases:
        await (db.update(db.legalCases)..where((t) => t.id.equals(rowId))).write(
              LegalCasesCompanion(
                deletedAt: Value(at),
                updatedAt: Value(at),
              ),
            );
      case SyncTables.caseSteps:
        await (db.update(db.caseSteps)..where((t) => t.id.equals(rowId))).write(
              CaseStepsCompanion(
                deletedAt: Value(at),
                updatedAt: Value(at),
              ),
            );
      default:
        throw ArgumentError('Unknown table: $table');
    }

    await _enqueue(
      table: table,
      rowId: rowId,
      operation: SyncOperation.delete.name,
      payload: null,
      at: at,
    );
  }

  /// Reads the ids of rows in [table] whose [column] equals [parentId].
  Future<List<String>> _readIds(
    String table,
    String column,
    String parentId,
  ) async {
    // Each table has exactly one parent column, so the pair (table, column) is
    // validated against a fixed map instead of trusting a free-form string.
    if (!const {
      SyncTables.categories,
      SyncTables.subcategories,
      SyncTables.legalCases,
      SyncTables.caseSteps,
    }.contains(table)) {
      throw ArgumentError('Unknown table: $table');
    }
    // The column that points at this table's parent.
    const parentColumnOf = <String, String>{
      SyncTables.categories: '',
      SyncTables.subcategories: 'category_id',
      SyncTables.legalCases: 'subcategory_id',
      SyncTables.caseSteps: 'case_id',
    };
    if (parentColumnOf[table] != column) {
      throw ArgumentError('Unknown column $column for table $table');
    }

    final rows = await db.customSelect(
      'SELECT id FROM $table WHERE $column = ?1 AND deleted_at IS NULL',
      variables: [Variable.withString(parentId)],
      readsFrom: {_readSourceFor(table)},
    ).get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  /// Maps a table name to the drift table used to watch it.
  ResultSetImplementation<dynamic, dynamic> _readSourceFor(String table) {
    switch (table) {
      case SyncTables.categories:
        return db.categories;
      case SyncTables.subcategories:
        return db.subcategories;
      case SyncTables.legalCases:
        return db.legalCases;
      case SyncTables.caseSteps:
        return db.caseSteps;
      default:
        throw ArgumentError('Unknown table: $table');
    }
  }

  /// Appends one operation to the outbox.
  ///
  /// Any earlier queued operation for the same row is dropped first, so five
  /// offline edits collapse into a single push carrying the final state. That
  /// keeps the queue from growing without bound and avoids replaying stale
  /// values over the server's newer ones.
  Future<void> _enqueue({
    required String table,
    required String rowId,
    required String operation,
    required Map<String, dynamic>? payload,
    required DateTime at,
  }) async {
    await (db.delete(db.syncQueue)
          ..where(
            (t) => t.targetTable.equals(table) & t.rowId.equals(rowId),
          ))
        .go();

    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: _uuid.v4(),
            targetTable: table,
            rowId: rowId,
            operation: operation,
            payload: Value(payload == null ? null : jsonEncode(payload)),
            createdAt: at,
          ),
        );
  }
}
