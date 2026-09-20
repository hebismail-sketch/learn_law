import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/legal_case_entity.dart';

class AdminEditCaseScreen extends StatefulWidget {
  final LegalCaseEntity legalCase;

  const AdminEditCaseScreen({
    super.key,
    required this.legalCase,
  });

  @override
  State<AdminEditCaseScreen> createState() => _AdminEditCaseScreenState();
}

class _AdminEditCaseScreenState extends State<AdminEditCaseScreen> {
  final _supabase = Supabase.instance.client;

  late TextEditingController _titleController;
  late TextEditingController _descController;

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _steps = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.legalCase.name);
    _descController = TextEditingController(text: widget.legalCase.description ?? '');
    _fetchCaseSteps();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // Fetch existing steps for this case
  Future<void> _fetchCaseSteps() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('case_steps')
          .select()
          .eq('case_id', widget.legalCase.id)
          .order('step_number', ascending: true);

      setState(() {
        _steps = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('فشل جلب خطوات القضية: $e', isError: true);
    }
  }

  // Update case details and steps in Supabase
  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('يرجى إدخال اسم القضية', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Update legal case info
      await _supabase.from('legal_cases').update({
        'title': title,
        'description': _descController.text.trim(),
      }).eq('id', widget.legalCase.id);

      // 2. Update each step
      for (final step in _steps) {
        if (step['id'] != null) {
          await _supabase.from('case_steps').update({
            'title': step['title'] ?? '',
            'short_description': step['short_description'] ?? '',
          }).eq('id', step['id']);
        }
      }

      setState(() => _isSaving = false);
      if (mounted) {
        _showSnackBar('تم حفظ التعديلات بنجاح! 🎉');
        Navigator.pop(context, true); // Return true to indicate change
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('حدث خطأ أثناء التعديل: $e', isError: true);
    }
  }

  // Show edit dialog for a single step
  void _editStepDialog(int index) {
    final step = _steps[index];
    final stepTitleCtrl = TextEditingController(text: step['title'] ?? '');
    final stepDescCtrl = TextEditingController(text: step['short_description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل الخطوة رقم (${index + 1})', textAlign: TextAlign.right),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stepTitleCtrl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'عنوان الخطوة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stepDescCtrl,
                textAlign: TextAlign.right,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل الخطوة',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _steps[index]['title'] = stepTitleCtrl.text.trim();
                _steps[index]['short_description'] = stepDescCtrl.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text('حفظ محلياً'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
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
          'تعديل بيانات ومسار القضية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Case Info card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'بيانات القضية',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Divider(),
                          TextField(
                            controller: _titleController,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              labelText: 'اسم القضية',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descController,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'الوصف المختصر',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Case Steps section
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'خطوات ومسار القضية',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Divider(),
                          if (_steps.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('لا توجد خطوات مسجلة لهذه القضية'),
                              ),
                            )
                          else
                            ...List.generate(_steps.length, (index) {
                              final step = _steps[index];
                              return ListTile(
                                leading: IconButton(
                                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                                  onPressed: () => _editStepDialog(index),
                                  tooltip: 'تعديل نصوص الخطوة',
                                ),
                                title: Text(
                                  step['title'] ?? '',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  step['short_description'] ?? '',
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'حفظ كافة التعديلات',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
