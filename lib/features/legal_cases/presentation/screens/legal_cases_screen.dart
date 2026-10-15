import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/injection_container.dart';
import '../../../../core/sync/local_data_source.dart';
import '../../domain/entities/subcategory_entity.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import '../widgets/roadmap_list_tile.dart';
import '../widgets/starry_background.dart';
import 'case_roadmap_screen.dart';
import 'admin_edit_case_screen.dart';

class LegalCasesScreen extends StatelessWidget {
  final SubcategoryEntity subcategory;

  const LegalCasesScreen({super.key, required this.subcategory});

  // Check if current user is the authorized administrator
  bool _isAdmin() {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && user.email?.toLowerCase() == 'heba@gmail.com';
  }

  // Delete case and all associated steps with confirmation dialog
  Future<void> _deleteCase(
    BuildContext context,
    LegalCaseEntity legalCase,
  ) async {
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
            child: const Text(
              'حذف نهائي',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Soft delete via the local database, which also soft deletes the steps
      // and queues one operation per row so other devices learn about it.
      await sl<LocalDataSource>().deleteLegalCase(id: legalCase.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حذف القضية بنجاح 🗑️',
              textAlign: TextAlign.right,
            ),
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
            content: Text(
              'حدث خطأ أثناء الحذف: $e',
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminUser = _isAdmin();

    return rebuildWithAppTheme(
      (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          title: Text(
            subcategory.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
          actions: const [ThemeToggleButton()],
        ),
        body: StarryBackground(
          child: BlocBuilder<LegalCubit, LegalState>(
            builder: (context, state) {
              if (state is LegalLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                );
              } else if (state is LegalCasesLoaded) {
                final cases = state.legalCases;
                if (cases.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد قضايا مضافة في هذا القسم',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 20.0,
                  ),
                  itemCount: cases.length,
                  itemBuilder: (context, index) {
                    final legalCase = cases[index];
                    return RoadmapListTile(
                      title: legalCase.name,
                      subtitle: legalCase.description,
                      index: index,
                      icon: Icons.article_rounded,
                      actions: isAdminUser
                          ? [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFF87171),
                                ),
                                tooltip: 'حذف القضية',
                                onPressed: () =>
                                    _deleteCase(context, legalCase),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_note_rounded,
                                  color: Color(0xFF7DD3FC),
                                ),
                                tooltip: 'تعديل القضية وخطواتها',
                                onPressed: () async {
                                  final updated = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminEditCaseScreen(
                                        legalCase: legalCase,
                                      ),
                                    ),
                                  );
                                  if (updated == true && context.mounted) {
                                    context.read<LegalCubit>().fetchLegalCases(
                                      subcategory.id,
                                    );
                                  }
                                },
                              ),
                            ]
                          : const [],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (_) =>
                                  sl<LegalCubit>()
                                    ..fetchCaseSteps(legalCase.id),
                              child: CaseRoadmapScreen(legalCase: legalCase),
                            ),
                          ),
                        );
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
      ),
    );
  }
}
