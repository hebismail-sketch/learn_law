import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/injection_container.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../bloc/legal_cubit.dart';
import '../widgets/starry_background.dart';
import 'case_roadmap_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Search cases in Supabase with debounce to avoid excessive requests
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }

    // Wait 400 milliseconds after user stops typing
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(trimmed);
    });
  }

  // Query Supabase for matching cases and their subcategories
  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final response = await _supabase
          .from('legal_cases')
          .select(
            'id, title, description, subcategory_id, subcategories(id, name)',
          )
          .ilike('title', '%$query%');

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء البحث: $e',
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101D),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white),
          cursorColor: const Color(0xFF38BDF8),
          decoration: InputDecoration(
            hintText: 'ابحث باسم القضية...',
            border: InputBorder.none,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : const Icon(Icons.search, color: Color(0xFF38BDF8)),
          ),
          onChanged: _onSearchChanged,
        ),
        elevation: 0,
      ),
      body: StarryBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      );
    }

    if (!_hasSearched || _searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_rounded,
              size: 72,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(height: 16),
            Text(
              'اكتب اسم أي قضية للبحث عنها في كل الأقسام',
              style: const TextStyle(fontSize: 15, color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_off_outlined,
              size: 64,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 16),
            const Text(
              'لم يتم العثور على أي نتائج مطابقة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final subcategoryData = item['subcategories'] as Map<String, dynamic>?;
        final subcategoryName = subcategoryData?['name'] ?? 'قسم عام';

        final legalCaseEntity = LegalCaseEntity(
          id: item['id'] as String,
          subcategoryId: item['subcategory_id'] as String,
          name: item['title'] ?? '',
          description: item['description'],
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          decoration: BoxDecoration(
            color: const Color(0xFF161F36),
            borderRadius: BorderRadius.circular(28.0),
            border: Border.all(color: const Color(0xFF35425D)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              leading: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              trailing: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF202B43),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  Icons.article_rounded,
                  color: Color(0xFF38BDF8),
                  size: 22,
                ),
              ),
              title: Text(
                legalCaseEntity.name,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (legalCaseEntity.description != null &&
                      legalCaseEntity.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      legalCaseEntity.description!,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF082F49),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      subcategoryName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7DD3FC),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () {
                // Open case roadmap directly from search result
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) =>
                          sl<LegalCubit>()..fetchCaseSteps(legalCaseEntity.id),
                      child: CaseRoadmapScreen(legalCase: legalCaseEntity),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
