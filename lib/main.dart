import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/injection_container.dart';
import 'core/sync/sync_manager.dart';
import 'features/legal_cases/presentation/bloc/legal_cubit.dart';
import 'features/legal_cases/presentation/screens/categories_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Supabase.initialize(
    url: 'https://ptsfjeersiesgjtvcjkh.supabase.co',
    anonKey: 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O',
  );


  await initDependencies();

  // Kick off the first sync without awaiting it: the app should render the
  // cached rows immediately and fill in the rest when the network answers.
  // Any later network change is picked up by the connectivity subscription.
  final syncManager = sl<SyncManager>();
  syncManager.listenToConnectivity();
  unawaited(syncManager.sync());

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