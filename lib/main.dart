import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/injection_container.dart';
import 'core/sync/sync_manager.dart';
import 'core/sync/sync_types.dart';
import 'features/legal_cases/presentation/bloc/legal_cubit.dart';
import 'features/legal_cases/presentation/screens/categories_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Supabase.initialize(
    url: 'https://ptsfjeersiesgjtvcjkh.supabase.co',
    anonKey: 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O',
  );


  await initDependencies();

  // Wait for the first sync before rendering, so the app opens showing real
  // data instead of an empty list that has to be filled in behind the user.
  // sync() reports offline or failure as a result rather than throwing, so a
  // device with no network still opens on whatever is cached locally.
  final syncManager = sl<SyncManager>();
  syncManager.listenToConnectivity();
  // Capped so a server that never answers cannot hold the app on a blank
  // screen. Whatever was cached is already in the database by this point.
  await syncManager.sync().timeout(
        const Duration(seconds: 10),
        onTimeout: () => const SyncResult(status: SyncStatus.failure),
      );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'الدليل القانوني',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) => sl<LegalCubit>(),
        child: const CategoriesScreen(),
      ),
    );
  }
}