import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../widgets/roadmap_editor.dart';

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
  // Structured branch inputs per step id, kept in sync with the dialog editor.
  final Map<String, List<BranchInputData>> _stepBranches = {};
  // Ids of steps the admin deleted from the editor; removed on save.
  final Set<String> _deletedStepIds = {};

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
    for (final list in _stepBranches.values) {
      for (final b in list) {
        b.dispose();
      }
    }
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
        final decoded =
            decodeStepDescription((step['short_description'] ?? '').toString());
        step['short_description'] = decoded.description;
        step['branches'] = decoded.branches;
        _stepBranches[step['id'].toString()] = decoded.branches;
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

  /// Key used to store the branch model for a step (new steps get one too).
  String _stepKey(Map<String, dynamic> step, int index) {
    final id = step['id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    // Unsaved steps are identified by a stable local key created with the row.
    return (step['__local_key'] ??= 'new_$index').toString();
  }

  /// Adds a brand-new main step at the end of the roadmap.
  void _addStep() {
    setState(() {
      final index = _steps.length;
      final fresh = <String, dynamic>{
        'id': null,
        '__local_key': 'new_${DateTime.now().microsecondsSinceEpoch}',
        'title': '',
        'short_description': '',
        'branches': <BranchInputData>[],
        'step_number': index + 1,
      };
      _steps.add(fresh);
      _stepBranches[_stepKey(fresh, index)] = <BranchInputData>[];

      // Existing path links still point at step numbers, which do not change
      // because the new step is appended at the end.
    });
  }

  /// Removes a main step from the roadmap (and its row on save).
  void _removeStep(int index) {
    if (index < 0 || index >= _steps.length) return;

    setState(() {
      final removed = _steps.removeAt(index);
      final id = removed['id']?.toString();
      if (id != null && id.isNotEmpty) _deletedStepIds.add(id);

      // The locals updated their step numbers, so path links that pointed at
      // a shifted step must follow.
      for (final link in _allBranches()) {
        final target = link.nextStepNumber;
        if (target == null) continue;
        if (target == index + 1) {
          link.nextStepNumber = null;
          link.nextStepTitle = null;
        } else if (target > index + 1) {
          link.nextStepNumber = target - 1;
        }
      }
    });
  }

  /// Every top-level branch currently held by the editor.
  Iterable<BranchInputData> _allBranches() sync* {
    for (final step in _steps) {
      final list = _stepBranches[_stepKey(step, _steps.indexOf(step))];
      if (list == null) continue;
      yield* list;
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

      // 2. Drop steps the admin deleted in the editor.
      for (final id in _deletedStepIds) {
        await _supabase.from('case_steps').delete().eq('id', id);
      }
      _deletedStepIds.clear();

      // 3. Upsert every step in order. Existing rows are updated, steps added
      //    from the editor are inserted and keep their new ids so a second save
      //    updates them instead of duplicating.
      for (int i = 0; i < _steps.length; i++) {
        final step = _steps[i];
        final index = i;
        final key = _stepKey(step, index);
        final branches = _stepBranches[key] ?? <BranchInputData>[];

        final payload = <String, dynamic>{
          'case_id': widget.legalCase.id,
          'step_number': index + 1,
          'title': step['title'] ?? '',
          'short_description': encodeStepDescription(
            stepNumber: index + 1,
            description: (step['short_description'] ?? '').toString(),
            branches: branches,
          ),
        };

        final id = step['id']?.toString();
        if (id == null || id.isEmpty) {
          final inserted = await _supabase
              .from('case_steps')
              .insert(payload)
              .select()
              .single();

          step['id'] = inserted['id'];
          step['step_number'] = index + 1;

          // Re-key the branch model now that the step has a real id.
          if (key != step['id'].toString()) {
            _stepBranches[step['id'].toString()] = branches;
            _stepBranches.remove(key);
          }
        } else {
          await _supabase.from('case_steps').update(payload).eq('id', id);
          step['step_number'] = index + 1;
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

  // Opens the full roadmap editor for the whole case: every step, its branches,
  // and the path links that move a branch on to the next step/answer state.
  Future<void> _openRoadmapEditor() async {
    // Build fresh input models from the loaded rows. The editor owns them and
    // disposes them on pop, so the parent's list is never invalidated.
    final inputs = <StepInputData>[];
    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      final input = StepInputData(
        title: (step['title'] ?? '').toString(),
        desc: (step['short_description'] ?? '').toString(),
      );
      final branches = _stepBranches[_stepKey(step, i)] ?? <BranchInputData>[];
      input.branches.addAll(branches.map(cloneBranch));
      inputs.add(input);
    }

    final result = await Navigator.push<_RoadmapEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _CaseRoadmapEditorScreen(
          caseTitle: widget.legalCase.name,
          initialSteps: inputs,
        ),
      ),
    );

    if (!mounted || result == null) return;

    // Copy plain values out before the editor's controllers are disposed.
    final newSteps = result.steps
        .map((s) => <String, dynamic>{
              'id': null,
              'title': s.titleController.text.trim(),
              'short_description': s.descController.text.trim(),
            })
        .toList();
    final newBranches = result.steps
        .map((s) => s.branches.map(cloneBranch).toList())
        .toList();

    setState(() {
      // Steps kept from the DB are matched back by position so their ids (and
      // therefore their rows) survive the round trip; anything past the old
      // length is genuinely new and is inserted on save.
      final kept = <Map<String, dynamic>>[];
      for (int i = 0; i < newSteps.length; i++) {
        if (i < _steps.length) {
          final existing = _steps[i];
          final id = existing['id']?.toString();
          // Only reuse a row when the case had no deletions in flight.
          if (id != null && _deletedStepIds.isEmpty) {
            kept.add({
              ...existing,
              'title': newSteps[i]['title'],
              'short_description': newSteps[i]['short_description'],
            });
            _stepBranches[id] = newBranches[i];
            continue;
          }
        }
        final fresh = <String, dynamic>{
          'id': null,
          '__local_key': 'new_${DateTime.now().microsecondsSinceEpoch}_$i',
          ...newSteps[i],
        };
        kept.add(fresh);
        _stepBranches[_stepKey(fresh, i)] = newBranches[i];
      }

      // Steps the admin dropped in the editor are deleted on save.
      for (int i = newSteps.length; i < _steps.length; i++) {
        final id = _steps[i]['id']?.toString();
        if (id != null && id.isNotEmpty) _deletedStepIds.add(id);
      }

      _steps = kept;
    });
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
                              final branchCount = (_stepBranches[_stepKey(step, index)] ??
                                      <BranchInputData>[])
                                  .length;
                              return ListTile(
                                leading: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.redAccent),
                                  onPressed: () => _removeStep(index),
                                  tooltip: 'حذف هذه الخطوة من المسار',
                                ),
                                title: Row(
                                  children: [
                                    if (step['id'] == null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                              color: Colors.green.shade300),
                                        ),
                                        child: Text(
                                          'خطوة جديدة',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        (step['title'] ?? '').toString().isEmpty
                                            ? 'بدون عنوان'
                                            : step['title'],
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
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
                                    if (branchCount > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '🌿 يتفرع منها $branchCount مسار(ات)',
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _addStep,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('إضافة خطوة'),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _openRoadmapEditor,
                                icon: const Icon(Icons.account_tree_rounded, size: 18),
                                label: const Text('تعديل الفروع والمسارات'),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'من داخل محرر المسارات: أضف فرعاً (قبول/رفض/طور ثاني/فرع أخر)، '
                              'ثم افتح «مسار هذا الفرع» لإضافة تفريع جديد له، '
                              'أو اضغط «الانتقال للخطوة التالية» لربط المسار بالخطوة التي تليه.',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 11, height: 1.6, color: Colors.grey),
                            ),
                          ),
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

// ==============================================================================
// Full-case roadmap editor
// ==============================================================================

/// What the roadmap editor hands back when the admin confirms: the whole tree
/// (every step, in order) with its branches and path links. The parent owns the
/// values after this, so it copies the text out before the controllers die.
class _RoadmapEditResult {
  final List<StepInputData> steps;

  const _RoadmapEditResult(this.steps);
}

/// Multi-step editor: the admin can add steps, add branches to a step or to an
/// existing path ("إضافة تفريع لهذا المسار"), and point a path at the step that
/// follows it ("الانتقال للخطوة التالية").
class _CaseRoadmapEditorScreen extends StatefulWidget {
  final String caseTitle;
  final List<StepInputData> initialSteps;

  const _CaseRoadmapEditorScreen({
    required this.caseTitle,
    required this.initialSteps,
  });

  @override
  State<_CaseRoadmapEditorScreen> createState() =>
      _CaseRoadmapEditorScreenState();
}

class _CaseRoadmapEditorScreenState extends State<_CaseRoadmapEditorScreen> {
  late final List<StepInputData> _steps;

  @override
  void initState() {
    super.initState();
    // The parent hands in fresh clones; this screen owns and disposes them.
    _steps = List<StepInputData>.from(widget.initialSteps);
    if (_steps.isEmpty) _steps.add(StepInputData());
  }

  @override
  void dispose() {
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  void _addStep() {
    setState(() => _steps.add(StepInputData()));
  }

  void _removeStep(int index) {
    if (index < 0 || index >= _steps.length) return;

    setState(() {
      final removed = _steps.removeAt(index);

      // Path links point at step numbers, so drop the ones aimed at the removed
      // step and shift the rest down to match the new numbering.
      for (final step in _steps) {
        for (final branch in step.branches) {
          _repairLink(branch, removedIndex: index);
        }
      }

      if (_steps.isEmpty) _steps.add(StepInputData());

      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
    });
  }

  void _repairLink(BranchInputData branch, {required int removedIndex}) {
    final target = branch.nextStepNumber;
    if (target != null) {
      if (target == removedIndex + 1) {
        branch.nextStepNumber = null;
        branch.nextStepTitle = null;
      } else if (target > removedIndex + 1) {
        branch.nextStepNumber = target - 1;
      }
    }
    for (final sub in branch.subBranches) {
      _repairLink(sub, removedIndex: removedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'محرر خطوات ومسارات القضية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'القضية: ${widget.caseTitle}\n'
                'أضف خطوة، ثم أضف لها فرعاً (قبول/رفض/طور ثاني/فرع أخر). '
                'داخل الفرع اضغط «إضافة تفريع لهذا المسار» لتفريعه من جديد، '
                'أو «الانتقال للخطوة التالية» لتوصيل هذا المسار بالخطوة التالية في القضية.',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
            const SizedBox(height: 12),
            RoadmapEditor(
              steps: _steps,
              onAddStep: _addStep,
              onRemoveStep: _removeStep,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'معاينة الشكل النهائي',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  RoadmapPreview(steps: _steps),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _RoadmapEditResult(List.of(_steps))),
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                'اعتماد التعديلات والعودة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'ملاحظة: لا تُحفظ التعديلات في قاعدة البيانات إلا بعد الضغط على «حفظ كافة التعديلات» في الشاشة السابقة.',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
