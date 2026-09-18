import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/injection_container.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import 'subcategories_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch main categories on initialization
    context.read<LegalCubit>().fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'دليل المحاماة - التصنيفات الرئيسية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: BlocBuilder<LegalCubit, LegalState>(
        builder: (context, state) {
          if (state is LegalLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CategoriesLoaded) {
            final categories = state.categories;
            if (categories.isEmpty) {
              return const Center(child: Text('لا توجد تصنيفات مضافة حالياً'));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16.0),
                      onTap: () {
                        // Navigate to subcategories screen with provided category id
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (_) => sl<LegalCubit>()..fetchSubcategories(category.id),
                              child: SubcategoriesScreen(category: category),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22.0, horizontal: 20.0),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.grey),
                            const Spacer(),
                            Expanded(
                              flex: 8,
                              child: Text(
                                category.name,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.gavel_rounded,
                                color: Theme.of(context).primaryColor,
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