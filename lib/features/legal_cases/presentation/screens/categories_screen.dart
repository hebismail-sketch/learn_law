import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/injection_container.dart';
import '../../../../core/sync/sync_refresh_listener.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import 'subcategories_screen.dart';
import 'admin_hub_screen.dart';
import 'admin_login_screen.dart';
import 'global_search_screen.dart';
import '../widgets/roadmap_list_tile.dart';
import '../widgets/starry_background.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  // Secret tap counter and timer to enter admin mode
  int _secretTapCount = 0;
  Timer? _secretTapTimer;

  @override
  void initState() {
    super.initState();
    // Fetch main categories on initialization
    context.read<LegalCubit>().fetchCategories();
  }

  @override
  void dispose() {
    _secretTapTimer?.cancel();
    super.dispose();
  }

  // Handle secret 5-tap sequence on app bar title
  void _handleSecretTap() {
    _secretTapTimer?.cancel();
    _secretTapCount++;

    // Reset counter if taps stop for more than 2 seconds
    _secretTapTimer = Timer(const Duration(seconds: 2), () {
      _secretTapCount = 0;
    });

    // Check if 5 consecutive taps reached
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _secretTapTimer?.cancel();
      _openAdminGate();
    }
  }

  // Navigate to Admin Login or directly to Admin Hub if already authenticated as the authorized admin
  Future<void> _openAdminGate() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    // Check if user is currently logged in AND matches the designated admin email
    final isAuthorizedAdmin =
        currentUser != null &&
        currentUser.email?.toLowerCase() == 'heba@gmail.com';

    final targetScreen = isAuthorizedAdmin
        ? const AdminHubScreen()
        : const AdminLoginScreen();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => targetScreen),
    );

    // Refresh categories when returning from admin
    if (mounted) {
      context.read<LegalCubit>().fetchCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return rebuildWithAppTheme(
      (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          // Secret tap gesture on the title
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleSecretTap,
            child: const Text(
              'دليل المحاماة - التصنيفات الرئيسية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          centerTitle: true,
          elevation: 0,
          actions: const [ThemeToggleButton()],
        ),
        body: StarryBackground(
          child: Column(
            children: [
              // Global Search Bar Trigger
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28.0),
                  elevation: 5,
                  shadowColor: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28.0),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GlobalSearchScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18.0,
                        vertical: 14.0,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: Color(0xFF0EA5E9),
                          ),
                          const Spacer(),
                          Text(
                            'ابحث عن أي قضية في التطبيق...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF0EA5E9),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Categories List
              Expanded(
                child: SyncRefreshListener(
                  onSyncComplete: () =>
                      context.read<LegalCubit>().refreshCategories(),
                  child: BlocBuilder<LegalCubit, LegalState>(
                    builder: (context, state) {
                      if (state is LegalLoading) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF38BDF8),
                          ),
                        );
                      } else if (state is CategoriesLoaded) {
                        final categories = state.categories;
                        if (categories.isEmpty) {
                          return Center(
                            child: Text(
                              'لا توجد تصنيفات مضافة حالياً',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        }
                        return LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      18,
                                      20,
                                      66,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (
                                          var index = 0;
                                          index < categories.length;
                                          index++
                                        )
                                          RoadmapListTile(
                                            title: categories[index].name,
                                            index: index,
                                            icon: Icons.folder_open_rounded,
                                            onTap: () {
                                              final category =
                                                  categories[index];
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => BlocProvider(
                                                    create: (_) =>
                                                        sl<LegalCubit>()
                                                          ..fetchSubcategories(
                                                            category.id,
                                                          ),
                                                    child: SubcategoriesScreen(
                                                      category: category,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                        );
                      } else if (state is LegalError) {
                        return Center(
                          child: Text(
                            state.message,
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
