import 'dart:convert';
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

      final rawList = List<Map<String, dynamic>>.from(response);

      // Parse branches if encoded in short_description
      for (final step in rawList) {
        String rawDesc = step['short_description'] ?? '';
        List<Map<String, dynamic>> branches = [];

        if (rawDesc.startsWith('__BRANCHES_JSON__')) {
          try {
            final jsonStr = rawDesc.replaceFirst('__BRANCHES_JSON__', '');
            final Map<String, dynamic> data = jsonDecode(jsonStr);
            rawDesc = data['main_description'] ?? '';
            final list = data['branches'] as List<dynamic>?;
            if (list != null) {
              branches = list.map((b) => Map<String, dynamic>.from(b)).toList();
            }
          } catch (_) {}
        }
        step['short_description'] = rawDesc;
        step['branches'] = branches;
      }

      setState(() {
        _steps = rawList;
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
          String finalDesc = step['short_description'] ?? '';
          final branches = step['branches'] as List<dynamic>?;

          if (branches != null && branches.isNotEmpty) {
            final validBranches = branches
                .where((b) => (b['title'] ?? '').toString().trim().isNotEmpty)
                .toList();

            if (validBranches.isNotEmpty) {
              final payload = {
                'main_description': finalDesc,
                'branches': validBranches,
              };
              finalDesc = '__BRANCHES_JSON__' + jsonEncode(payload);
            }
          }

          await _supabase.from('case_steps').update({
            'title': step['title'] ?? '',
            'short_description': finalDesc,
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

  // Show edit dialog for a single step with branches support
  void _editStepDialog(int index) {
    final step = _steps[index];
    final stepTitleCtrl = TextEditingController(text: step['title'] ?? '');
    final stepDescCtrl = TextEditingController(text: step['short_description'] ?? '');

    // Clone branches for dialog
    final existingBranches = (step['branches'] as List<dynamic>?) ?? [];
    final List<Map<String, TextEditingController>> branchControllers = existingBranches.map((b) {
      return {
        'title': TextEditingController(text: b['title'] ?? ''),
        'description': TextEditingController(text: b['description'] ?? ''),
      };
    }).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: Text('تعديل الخطوة رقم (${index + 1})', textAlign: TextAlign.right),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: stepTitleCtrl,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الخطوة الرئيسي',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stepDescCtrl,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'تفاصيل وشرح الخطوة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'إضافة مسار متفرع',
                          icon: const Icon(Icons.alt_route_rounded, color: Colors.amber),
                          onSelected: (val) {
                            setDialogState(() {
                              branchControllers.add({
                                'title': TextEditingController(text: val),
                                'description': TextEditingController(),
                              });
                            });
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'في حالة القبول',
                              child: Text('🟢 في حالة القبول', textAlign: TextAlign.right),
                            ),
                            const PopupMenuItem(
                              value: 'في حالة الرفض',
                              child: Text('🔴 في حالة الرفض', textAlign: TextAlign.right),
                            ),
                            const PopupMenuItem(
                              value: 'في حالة الاستئناف / الطعن',
                              child: Text('🟡 في حالة الاستئناف / الطعن', textAlign: TextAlign.right),
                            ),
                            const PopupMenuItem(
                              value: 'مسار مخصص آخر',
                              child: Text('⚪ مسار مخصص آخر', textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                        Text(
                          'المسارات المتفرعة (${branchControllers.length})',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                    ...List.generate(branchControllers.length, (bIdx) {
                      final bCtrl = branchControllers[bIdx];
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  onPressed: () {
                                    setDialogState(() {
                                      branchControllers.removeAt(bIdx);
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: bCtrl['title'],
                                    textAlign: TextAlign.right,
                                    decoration: InputDecoration(
                                      labelText: 'اسم المسار ${bIdx + 1}',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: bCtrl['description'],
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'خطوات وإجراءات هذا المسار',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _steps[index]['title'] = stepTitleCtrl.text.trim();
                    _steps[index]['short_description'] = stepDescCtrl.text.trim();
                    _steps[index]['branches'] = branchControllers
                        .where((b) => b['title']!.text.trim().isNotEmpty)
                        .map((b) => {
                              'title': b['title']!.text.trim(),
                              'description': b['description']!.text.trim(),
                              'sub_steps': <String>[],
                            })
                        .toList();
                  });
                  Navigator.pop(dialogCtx);
                },
                child: const Text('حفظ محلياً'),
              ),
            ],
          );
        },
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
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if ((step['short_description'] ?? '').toString().isNotEmpty)
                                      Text(
                                        step['short_description'] ?? '',
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (((step['branches'] as List<dynamic>?) ?? []).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '🌿 يتفرع منها ${((step['branches'] as List<dynamic>?) ?? []).length} مسار(ات)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                  ],
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
