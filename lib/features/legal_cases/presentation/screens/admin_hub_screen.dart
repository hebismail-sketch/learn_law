import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/roadmap_editor.dart';

class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subcategories = [];

  String? _selectedCategoryId;
  String? _selectedSubcategoryId;

  final _caseTitleController = TextEditingController();
  final _caseDescController = TextEditingController();

  // Dynamic step inputs
  final List<StepInputData> _stepInputs = [];
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    // Add default initial step
    _addStep();
  }

  @override
  void dispose() {
    _caseTitleController.dispose();
    _caseDescController.dispose();
    for (final step in _stepInputs) {
      step.dispose();
    }
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _stepInputs.add(StepInputData());
    });
  }

  void _removeStep(int index) {
    if (_stepInputs.length > 1 && index >= 0 && index < _stepInputs.length) {
      final removed = _stepInputs[index];
      setState(() {
        _stepInputs.removeAt(index);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        removed.dispose();
      });
    }
  }

  // Fetch all existing categories from Supabase
  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('categories').select().order('name');
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first['id'];
          _fetchSubcategories(_selectedCategoryId!);
        } else {
          _selectedCategoryId = null;
          _selectedSubcategoryId = null;
          _subcategories = [];
          _isLoading = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error loading categories: $e', isError: true);
    }
  }

  // Fetch subcategories for the selected category
  Future<void> _fetchSubcategories(String categoryId) async {
    try {
      final response = await _supabase
          .from('subcategories')
          .select()
          .eq('category_id', categoryId)
          .order('name');
      if (!mounted) return;
      setState(() {
        _subcategories = List<Map<String, dynamic>>.from(response);
        _selectedSubcategoryId =
            _subcategories.isNotEmpty ? _subcategories.first['id'] : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error loading subcategories: $e', isError: true);
    }
  }

  // Dialog to add a new category
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة تصنيف رئيسي جديد', textAlign: TextAlign.right),
        content: TextField(
          controller: nameController,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'مثال: القضايا المدنية اوالتجارية',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);

              setState(() => _isLoading = true);
              try {
                final inserted = await _supabase
                    .from('categories')
                    .insert({'name': name})
                    .select()
                    .single();
                _showSnackBar('تمت إضافة التصنيف بنجاح');
                await _fetchCategories();
                setState(() {
                  _selectedCategoryId = inserted['id'];
                });
                _fetchSubcategories(_selectedCategoryId!);
              } catch (e) {
                setState(() => _isLoading = false);
                _showSnackBar('فشل إضافة التصنيف: $e', isError: true);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // Dialog to add a new subcategory
  void _showAddSubcategoryDialog() {
    if (_selectedCategoryId == null) {
      _showSnackBar('يرجى اختيار تصنيف رئيسي أولاً', isError: true);
      return;
    }
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة قسم فرعي جديد', textAlign: TextAlign.right),
        content: TextField(
          controller: nameController,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'مثال: دعاوي النفقات والأجور',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);

              setState(() => _isLoading = true);
              try {
                final inserted = await _supabase
                    .from('subcategories')
                    .insert({
                      'category_id': _selectedCategoryId,
                      'name': name,
                    })
                    .select()
                    .single();
                _showSnackBar('تمت إضافة القسم الفرعي بنجاح');
                await _fetchSubcategories(_selectedCategoryId!);
                setState(() {
                  _selectedSubcategoryId = inserted['id'];
                });
              } catch (e) {
                setState(() => _isLoading = false);
                _showSnackBar('فشل إضافة القسم: $e', isError: true);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // Save the full case and all its roadmap steps
  Future<void> _saveFullCase() async {
    final title = _caseTitleController.text.trim();
    if (_selectedSubcategoryId == null) {
      _showSnackBar('يرجى تحديد القسم الفرعي التابع له القضية', isError: true);
      return;
    }
    if (title.isEmpty) {
      _showSnackBar('يرجى إدخال اسم القضية', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Insert legal case
      final caseResponse = await _supabase
          .from('legal_cases')
          .insert({
            'subcategory_id': _selectedSubcategoryId,
            'title': title,
            'description': _caseDescController.text.trim(),
          })
          .select()
          .single();

      final caseId = caseResponse['id'];

      // 2. Prepare steps payload
      final List<Map<String, dynamic>> stepsPayload = [];
      for (int i = 0; i < _stepInputs.length; i++) {
        final stepInput = _stepInputs[i];
        final stepTitle = stepInput.titleController.text.trim();
        final stepDesc = stepInput.descController.text.trim();

        if (stepTitle.isNotEmpty) {
          stepsPayload.add({
            'case_id': caseId,
            'step_number': i + 1,
            'title': stepTitle,
            'short_description': encodeStepDescription(
              description: stepDesc,
              branches: stepInput.branches,
            ),
          });
        }
      }

      // 3. Batch insert steps if present
      if (stepsPayload.isNotEmpty) {
        await _supabase.from('case_steps').insert(stepsPayload);
      }

      setState(() => _isSaving = false);
      _showSnackBar('تم حفظ ونشر القضية وكافة خطواتها بنجاح! 🎉');

      // Clear inputs safely
      _caseTitleController.clear();
      _caseDescController.clear();
      final oldInputs = List<StepInputData>.from(_stepInputs);
      setState(() {
        _stepInputs.clear();
        _addStep();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final s in oldInputs) {
          s.dispose();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnackBar('حدث خطأ أثناء الحفظ: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
           appBar: AppBar(
        title: const Text(
          'لوحة إدارة القضايا والمسارات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          // Refresh legal app content cache button
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'تحديث بيانات التطبيق',
            onPressed: () async {
              await _fetchCategories();
              if (mounted) {
                _showSnackBar('تم تحديث البيانات بنجاح 🔄');
              }
            },
          ),
          // Sign out button
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await _supabase.auth.signOut();
              if (!context.mounted) return;
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section: Category Selection and Creation
                  _buildCard(
                    title: '1. التصنيف الرئيسي والقسم الفرعي',
                    icon: Icons.category_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _showAddCategoryDialog,
                              icon: const Icon(Icons.add_circle, color: Colors.blue),
                              tooltip: 'إضافة تصنيف رئيسي جديد',
                            ),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _categories.any((cat) => cat['id'] == _selectedCategoryId)
                                    ? _selectedCategoryId
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'التصنيف الرئيسي',
                                  border: OutlineInputBorder(),
                                ),
                                isExpanded: true,
                                items: _categories.map((cat) {
                                  return DropdownMenuItem<String>(
                                    value: cat['id'] as String,
                                    child: Text(
                                      cat['name'] ?? '',
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null && val != _selectedCategoryId) {
                                    setState(() {
                                      _selectedCategoryId = val;
                                      _selectedSubcategoryId = null;
                                      _subcategories = [];
                                    });
                                    _fetchSubcategories(val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _showAddSubcategoryDialog,
                              icon: const Icon(Icons.add_circle, color: Colors.amber),
                              tooltip: 'إضافة قسم فرعي جديد',
                            ),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _subcategories.any((sub) => sub['id'] == _selectedSubcategoryId)
                                    ? _selectedSubcategoryId
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'القسم الفرعي',
                                  border: OutlineInputBorder(),
                                ),
                                isExpanded: true,
                                items: _subcategories.map((sub) {
                                  return DropdownMenuItem<String>(
                                    value: sub['id'] as String,
                                    child: Text(
                                      sub['name'] ?? '',
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedSubcategoryId = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section: Case Info
                  _buildCard(
                    title: '2. بيانات القضية الجديدة',
                    icon: Icons.gavel_rounded,
                    child: Column(
                      children: [
                        TextField(
                          controller: _caseTitleController,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            labelText: 'اسم القضية (مثال: دعوى نفقة صغار)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _caseDescController,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'وصف مختصر للقضية (اختياري)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section: Roadmap Steps
                  _buildCard(
                    title: '3. خطوات خريطة طريق سير القضية',
                    icon: Icons.timeline_rounded,
                    child: RoadmapEditor(
                      steps: _stepInputs,
                      onAddStep: _addStep,
                      onRemoveStep: _removeStep,
                      onChanged: () => setState(() {}),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section: Live preview of the resulting roadmap shape
                  _buildCard(
                    title: '4. معاينة الشكل النهائي للخريطة',
                    icon: Icons.visibility_rounded,
                    child: KeyedSubtree(
                      key: _previewKey,
                      child: RoadmapPreview(steps: _stepInputs),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveFullCase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_rounded),
                              SizedBox(width: 8),
                              Text(
                                'حفظ ونشر القضية في التطبيق',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: Colors.blue.shade700, size: 22),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }
}
