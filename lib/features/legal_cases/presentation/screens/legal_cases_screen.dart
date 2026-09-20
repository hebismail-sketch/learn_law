import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/injection_container.dart';
import '../../domain/entities/subcategory_entity.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import 'case_roadmap_screen.dart';
import 'admin_edit_case_screen.dart';

class LegalCasesScreen extends StatelessWidget {
  final SubcategoryEntity subcategory;

  const LegalCasesScreen({
    super.key,
    required this.subcategory,
  });

  // Check if current user is the authorized administrator
  bool _isAdmin() {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && user.email?.toLowerCase() == 'heba@gmail.com';
  }

  // Delete case and all associated steps with confirmation dialog
  Future<void> _deleteCase(BuildContext context, LegalCaseEntity legalCase) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تأكيد حذف القضية', textAlign: TextAlign.right),
        content: Text(
          'هل أنت متأكد من حذف قضية "${legalCase.name}" وجميع خطواتها نهائياً؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      // 1. Delete associated steps first
      await supabase.from('case_steps').delete().eq('case_id', legalCase.id);
      // 2. Delete the legal case
      await supabase.from('legal_cases').delete().eq('id', legalCase.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف القضية بنجاح 🗑️', textAlign: TextAlign.right),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the legal cases list
        context.read<LegalCubit>().fetchLegalCases(subcategory.id);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحذف: $e', textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminUser = _isAdmin();

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
                        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            // Show admin action buttons only to the authorized admin
                            if (isAdminUser) ...[
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                tooltip: 'حذف القضية',
                                onPressed: () => _deleteCase(context, legalCase),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                                tooltip: 'تعديل القضية وخطواتها',
                                onPressed: () async {
                                  final updated = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminEditCaseScreen(legalCase: legalCase),
                                    ),
                                  );
                                  if (updated == true && context.mounted) {
                                    context.read<LegalCubit>().fetchLegalCases(subcategory.id);
                                  }
                                },
                              ),
                            ] else
                              const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.grey),

                            const Spacer(),

                            // Case title and short description
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
