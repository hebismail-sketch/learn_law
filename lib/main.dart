import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/injection_container.dart';
import 'features/legal_cases/presentation/bloc/legal_cubit.dart';
import 'features/legal_cases/presentation/screens/categories_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Supabase.initialize(
    url: 'https://ptsfjeersiesgjtvcjkh.supabase.co',
    anonKey: 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O',
  );


  await initDependencies();

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