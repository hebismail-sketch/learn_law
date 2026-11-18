import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/sync/app_database.dart';
import 'package:learn_law/core/sync/connectivity_service.dart';
import 'package:learn_law/core/sync/sync_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Measures a real first download, page by page, against the live project.
///
/// Run with `flutter test test/download_timing_test.dart --reporter expanded`
/// and read the printed table. It answers "why is it still loading?" with
/// numbers instead of a guess: rows per page, per-table time, total time.
void main() {
  test('measure the real download', () async {
    const url = 'https://ptsfjeersiesgjtvcjkh.supabase.co';
    const key = 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';
    final supabase = SupabaseClient(
      url,
      key,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final manager = SyncManager(
      db: db,
      supabase: supabase,
      anonKey: key,
      connectivity: _Online(),
    );
    addTearDown(() async {
      await manager.dispose();
      await db.close();
      await supabase.dispose();
    });

    // A first run is measured with the same fetch the app uses; the progress
    // stream is emitted from inside the download, so its timing is measured
    // through the callback instead of a listener attached from outside.
    final started = DateTime.now();
    var lastTable = '';
    var lastAt = started;
    final perTable = <String, Duration>{};
    var tableStart = started;

    final subscription = manager.downloadProgress.listen((progress) {
      final now = DateTime.now();
      final since = now.difference(started).inMilliseconds;
      final page = now.difference(lastAt).inMilliseconds;
      lastAt = now;
      if (progress.table != lastTable) {
        if (lastTable.isNotEmpty) {
          perTable[lastTable] = now.difference(tableStart);
        }
        lastTable = progress.table;
        tableStart = now;
      }
      // ignore: avoid_print
      print(
        'PAGE ${since.toString().padLeft(6)}ms +${page.toString().padLeft(4)}ms '
        '${progress.table.padRight(14)} rows=${progress.downloaded}',
      );
    });

    final result = await manager.downloadAllContent(
      onProgress: (progress) {
        final now = DateTime.now();
        final since = now.difference(started).inMilliseconds;
        final page = now.difference(lastAt).inMilliseconds;
        lastAt = now;
        if (progress.table != lastTable) {
          if (lastTable.isNotEmpty) {
            perTable[lastTable] = now.difference(tableStart);
          }
          lastTable = progress.table;
          tableStart = now;
        }
        // ignore: avoid_print
        print(
          'PAGE ${since.toString().padLeft(6)}ms +${page.toString().padLeft(4)}ms '
          '${progress.table.padRight(14)} rows=${progress.downloaded}',
        );
      },
    );
    final total = DateTime.now().difference(started);
    await subscription.cancel();

    // ignore: avoid_print
    print('--- total ${total.inMilliseconds}ms, pulled=${result.pulled}');
    for (final entry in perTable.entries) {
      // ignore: avoid_print
      print('--- ${entry.key.padRight(14)} ${entry.value.inMilliseconds}ms');
    }

    expect(result.succeeded, isTrue);
  }, timeout: const Timeout(Duration(minutes: 15)));
}

class _Online extends ConnectivityService {
  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();
}
