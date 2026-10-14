import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/injection_container.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import '../widgets/roadmap_list_tile.dart';
import '../widgets/starry_background.dart';
import 'legal_cases_screen.dart';

class SubcategoriesScreen extends StatelessWidget {
  final CategoryEntity category;

  const SubcategoriesScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101D),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: StarryBackground(
        child: BlocBuilder<LegalCubit, LegalState>(
          builder: (context, state) {
            if (state is LegalLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              );
            } else if (state is SubcategoriesLoaded) {
              final subcategories = state.subcategories;
              if (subcategories.isEmpty) {
                return const Center(
                  child: Text(
                    'لا توجد أقسام فرعية مضافة',
                    style: TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 20.0,
                ),
                itemCount: subcategories.length,
                itemBuilder: (context, index) {
                  final subcategory = subcategories[index];
                  return RoadmapListTile(
                    title: subcategory.name,
                    index: index,
                    icon: Icons.folder_open_rounded,
                    maxWidth: 620,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider(
                            create: (_) =>
                                sl<LegalCubit>()
                                  ..fetchLegalCases(subcategory.id),
                            child: LegalCasesScreen(subcategory: subcategory),
                          ),
                        ),
                      );
                      if (context.mounted) {
                        context.read<LegalCubit>().fetchSubcategories(
                          category.id,
                        );
                      }
                    },
                  );
                },
              );
            } else if (state is LegalError) {
              return Center(
                child: Text(
                  'حدث خطأ: ${state.message}',
                  style: const TextStyle(color: Colors.red, fontSize: 16.0),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
