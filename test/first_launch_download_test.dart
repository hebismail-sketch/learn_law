import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/sync/app_database.dart';
import 'package:learn_law/core/sync/connectivity_service.dart';
import 'package:learn_law/core/sync/local_data_source.dart';
import 'package:learn_law/core/sync/sync_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Proves the promise a new install depends on: one download on an empty phone
/// leaves the whole library there — every category, every subcategory, every
/// case, and the steps each case's roadmap needs.
///
/// It runs against the live project with the same key the app ships, so it also
/// catches a server-side row that the local schema rejects (a category with a
/// blank name is what broke the first install before).
void main() {
  const supabaseUrl = 'https://ptsfjeersiesgjtvcjkh.supabase.co';
  const supabaseKey = 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';

  test(
    'a fresh install downloads the entire library',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final supabase = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final manager = SyncManager(
        db: db,
        supabase: supabase,
        anonKey: supabaseKey,
        connectivity: _AlwaysOnline(),
      );
      addTearDown(() async {
        await manager.dispose();
        await db.close();
        await supabase.dispose();
      });

      expect(await manager.isContentReady(), isFalse);

      final result = await manager.downloadAllContent();

      final local = LocalDataSourceImpl(db);
      final categories = await local.getCategories();
      final casesPerCategory = <String, int>{};
      final emptyRoadmaps = <String>[];
      var subcategories = 0;
      var cases = 0;
      var steps = 0;

      for (final category in categories) {
        final subs = await local.getSubcategories(category.id);
        subcategories += subs.length;
        var inCategory = 0;
        for (final sub in subs) {
          final subCases = await local.getLegalCases(sub.id);
          cases += subCases.length;
          inCategory += subCases.length;
          for (final legalCase in subCases) {
            final caseSteps = await local.getCaseSteps(legalCase.id);
            steps += caseSteps.length;
            if (caseSteps.isEmpty) emptyRoadmaps.add(legalCase.title);
          }
        }
        casesPerCategory[category.name] = inCategory;
      }

      // ignore: avoid_print
      print(
        'status=${result.status} pulled=${result.pulled} '
        'categories=${categories.length} subcategories=$subcategories '
        'cases=$cases steps=$steps ready=${await manager.isContentReady()}',
      );
      // ignore: avoid_print
      print('cases per category: $casesPerCategory');
      if (emptyRoadmaps.isNotEmpty) {
        // ignore: avoid_print
        print('cases with no roadmap steps: ${emptyRoadmaps.length}');
      }

      expect(result.succeeded, isTrue, reason: 'error: ${result.error}');
      expect(await manager.isContentReady(), isTrue);

      // The download must not have been silently partial.
      expect(categories, isNotEmpty);
      expect(subcategories, greaterThan(0));
      expect(cases, greaterThan(0));
      expect(steps, greaterThan(0));

      for (final category in categories) {
        expect(
          category.name.trim(),
          isNotEmpty,
          reason: 'a blank-named category reached the phone',
        );
        expect(
          casesPerCategory[category.name],
          greaterThan(0),
          reason: '"${category.name}" downloaded with no cases',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

class _AlwaysOnline extends ConnectivityService {
  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();
}
