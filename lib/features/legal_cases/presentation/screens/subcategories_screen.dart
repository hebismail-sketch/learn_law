import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/injection_container.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import 'legal_cases_screen.dart';

class SubcategoriesScreen extends StatelessWidget {
  final CategoryEntity category;

  const SubcategoriesScreen({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الأقسام الفرعية',
            onPressed: () {
              context.read<LegalCubit>().fetchSubcategories(category.id);
            },
          ),
        ],
      ),
      body: BlocBuilder<LegalCubit, LegalState>(
        builder: (context, state) {
          if (state is LegalLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is SubcategoriesLoaded) {
            final subcategories = state.subcategories;
            if (subcategories.isEmpty) {
              return const Center(child: Text('لا توجد أقسام فرعية مضافة'));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              itemCount: subcategories.length,
              itemBuilder: (context, index) {
                final subcategory = subcategories[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.08),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16.0),
                      onTap: () async {
                        // Navigate to legal cases screen and fetch associated cases
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (_) => sl<LegalCubit>()..fetchLegalCases(subcategory.id),
                              child: LegalCasesScreen(subcategory: subcategory),
                            ),
                          ),
                        );
                        // Refresh subcategories when returning
                        if (context.mounted) {
                          context.read<LegalCubit>().fetchSubcategories(category.id);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.grey),
                            const Spacer(),
                            Expanded(
                              flex: 8,
                              child: Text(
                                subcategory.name,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 17.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.folder_open_rounded,
                                color: Colors.amber.shade800,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
    );
  }
}