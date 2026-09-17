import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {

    context.read<LegalCubit>().fetchCategories();

    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل المحاماة - التصنيفات الرئيسية'),
        centerTitle: true,
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
              padding: const EdgeInsets.all(16.0),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {

                    },
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
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