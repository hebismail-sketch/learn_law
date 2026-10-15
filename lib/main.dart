import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
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

  final syncManager = sl<SyncManager>();
  syncManager.listenToConnectivity();
  runApp(const MyApp());

  unawaited(
    syncManager.sync().then((result) {
      if (result.status == SyncStatus.failure) {
        debugPrint('Background startup sync failed: ${result.error}');
      }
    }),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isLight,
      builder: (context, isLight, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'الدليل القانوني',
        theme: AppColors.theme,
        home: BlocProvider(
          create: (_) => sl<LegalCubit>(),
          child: const CategoriesScreen(),
        ),
      ),
    );
  }
}
