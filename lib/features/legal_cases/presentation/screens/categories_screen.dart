import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/injection_container.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import 'subcategories_screen.dart';
import 'admin_hub_screen.dart';
import 'admin_login_screen.dart';
import 'global_search_screen.dart';

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
    final isAuthorizedAdmin = currentUser != null &&
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
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
      ),
      body: Column(
        children: [
          // Global Search Bar Trigger
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.0),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.06),
              child: InkWell(
                borderRadius: BorderRadius.circular(14.0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GlobalSearchScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 20, color: Colors.blue.shade700),
                      const Spacer(),
                      Text(
                        'ابحث عن أي قضية في التطبيق...',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14.0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.search_rounded, color: Colors.blue.shade700, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Categories List
          Expanded(
            child: BlocBuilder<LegalCubit, LegalState>(
              builder: (context, state) {
                if (state is LegalLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is CategoriesLoaded) {
                  final categories = state.categories;
                  if (categories.isEmpty) {
                    return const Center(child: Text('لا توجد تصنيفات مضافة حالياً'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          trailing: const Icon(
                            Icons.folder_open_rounded,
                            color: Color(0xFF1E3A8A),
                            size: 28,
                          ),
                          leading: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                          title: Text(
                            category.name,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider(
                                  create: (_) => sl<LegalCubit>()..fetchSubcategories(category.id),
                                  child: SubcategoriesScreen(
                                    category: category,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
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
        ],
      ),
    );
  }
}
