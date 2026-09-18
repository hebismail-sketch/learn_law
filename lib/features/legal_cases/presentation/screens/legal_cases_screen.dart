import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/injection_container.dart';
import '../../domain/entities/subcategory_entity.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import 'case_roadmap_screen.dart';

class LegalCasesScreen extends StatelessWidget {
  final SubcategoryEntity subcategory;

  const LegalCasesScreen({
    super.key,
    required this.subcategory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          subcategory.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: BlocBuilder<LegalCubit, LegalState>(
        builder: (context, state) {
          if (state is LegalLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is LegalCasesLoaded) {
            final cases = state.legalCases;
            if (cases.isEmpty) {
              return const Center(child: Text('لا توجد قضايا مضافة في هذا القسم'));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              itemCount: cases.length,
              itemBuilder: (context, index) {
                final legalCase = cases[index];
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
                        // Navigate to case roadmap screen and fetch case steps
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (_) => sl<LegalCubit>()..fetchCaseSteps(legalCase.id),
                              child: CaseRoadmapScreen(legalCase: legalCase),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.grey),
                            const Spacer(),
                            Expanded(
                              flex: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    legalCase.name,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 17.0,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (legalCase.description != null && legalCase.description!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      legalCase.description!,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 13.0,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.article_rounded,
                                color: Colors.blue.shade700,
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