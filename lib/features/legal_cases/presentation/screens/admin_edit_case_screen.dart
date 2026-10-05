import 'package:flutter/material.dart';

import '../../../../core/sync/local_data_source.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../widgets/roadmap_editor.dart';
import '../../../../core/injection_container.dart';

class AdminEditCaseScreen extends StatefulWidget {
  final LegalCaseEntity legalCase;

  const AdminEditCaseScreen({super.key, required this.legalCase});

  @override
  State<AdminEditCaseScreen> createState() => _AdminEditCaseScreenState();
}

class _AdminEditCaseScreenState extends State<AdminEditCaseScreen> {
  // Writes go to the local database and are queued for sync, so the admin
  // screens work with no network exactly like the rest of the app.
  final LocalDataSource _local = sl<LocalDataSource>();

  late TextEditingController _titleController;
  late TextEditingController _descController;

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _steps = [];
  // Structured branch inputs per step id, kept in sync with the dialog editor.
  final Map<String, List<BranchInputData>> _stepBranches = {};
  // Ids of steps the admin deleted from the editor; removed on save.
  final Set<String> _deletedStepIds = {};

  // مسار الفولدرات: القسم الرئيسي ثم القسم الفرعي الذي تحتويه القضية.
  String? _categoryId;
  String _categoryName = '';
  String? _subcategoryId;
  String _subcategoryName = '';
  bool _isFolderLoading = true;
  bool _isFolderSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.legalCase.name);
    _descController = TextEditingController(
      text: widget.legalCase.description ?? '',
    );
    _subcategoryId = widget.legalCase.subcategoryId;
    _fetchCaseSteps();
    _fetchFolderPath();
  }

  // يجلب اسم القسم الفرعي والقسم الرئيسي الذي يقع تحته
  Future<void> _fetchFolderPath() async {
    try {
      final subId = widget.legalCase.subcategoryId;
      final sub = await _local.findSubcategory(subId);
      if (sub == null) {
        if (mounted) setState(() => _isFolderLoading = false);
        return;
      }
      final categories = await _local.getCategories();
      final category = categories
          .where((c) => c.id == sub.categoryId)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _subcategoryId = sub.id;
        _subcategoryName = sub.name;
        _categoryId = category?.id;
        _categoryName = category?.name ?? '';
        _isFolderLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFolderLoading = false);
      _showSnackBar('تعذّر تحميل مسار الفولدر: $e', isError: true);
    }
  }

  // ====== إدارة الفولدرات من شاشة تعديل القضية ======

  Future<void> _renameFolder({
    required String? id,
    required String table,
    required String currentName,
    required bool isCategory,
  }) async {
    if (id == null || _isFolderSaving) return;
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isCategory ? 'تعديل اسم الفولدر الكبير' : 'تعديل اسم الفولدر',
          textAlign: TextAlign.right,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'الاسم الجديد',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    if (name.isEmpty) {
      _showSnackBar('الاسم الجديد فاضي', isError: true);
      return;
    }
    if (name == currentName) return;
    setState(() => _isFolderSaving = true);
    try {
      await (isCategory
          ? _local.updateCategory(id: id, name: name)
          : _local.updateSubcategory(id: id, name: name));
      if (!mounted) return;
      setState(() {
        if (isCategory) {
          _categoryName = name;
        } else {
          _subcategoryName = name;
        }
      });
      _showSnackBar('تم تعديل اسم الفولدر بنجاح');
    } catch (e) {
      if (mounted) _showSnackBar('فشل تعديل الفولدر: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isFolderSaving = false);
    }
  }

  Future<void> _deleteFolder({
    required String? id,
    required String name,
    required bool isCategory,
  }) async {
    if (id == null || _isFolderSaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isCategory ? 'حذف الفولدر الكبير' : 'حذف الفولدر',
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCategory
                  ? 'سيتم حذف «$name» وكل الفولدرات الفرعية والقضايا والمراحل بداخلها نهائياً.'
                  : 'سيتم حذف «$name» وكل القضايا والمراحل بداخلها نهائياً.',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'لا يمكن التراجع عن هذه العملية.',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isFolderSaving = true);
    try {
      if (isCategory) {
        await _deleteCategoryTree(id);
      } else {
        await _deleteSubcategoryTree(id);
      }
      if (!mounted) return;
      _showSnackBar('تم حذف «$name» وكل ما بداخله');
      // ISSUE: القائمة التي فتحت هذه الشاشة تحتاج تحديثاً
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('فشل الحذف: $e', isError: true);
      setState(() => _isFolderSaving = false);
    }
  }

  // حذف تتابعي: القضايا ← مراحلها ← الأقسام الفرعية ← التصنيف
  // كل مستوى منLevels يتعامل مع الـ soft delete ويضع كل صف في الطابور، فتبقى
  // الأجهزة الأخرى على علم بالحذف.
  Future<void> _deleteCategoryTree(String categoryId) async {
    for (final sub in await _local.getSubcategories(categoryId)) {
      await _deleteSubcategoryTree(sub.id);
    }
    await _local.deleteCategory(id: categoryId);
  }

  Future<void> _deleteSubcategoryTree(String subId) async {
    for (final legalCase in await _local.getLegalCases(subId)) {
      await _local.deleteLegalCase(id: legalCase.id);
    }
    await _local.deleteSubcategory(id: subId);
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
      final rawList = (await _local.getCaseSteps(widget.legalCase.id))
          .map(
            (s) => <String, dynamic>{
              'id': s.id,
              'case_id': s.caseId,
              'step_number': s.stepNumber,
              'title': s.title,
              'short_description': s.shortDescription,
            },
          )
          .toList();

      // Parse branches if encoded in short_description
      for (final step in rawList) {
        final decoded = decodeStepDescription(
          (step['short_description'] ?? '').toString(),
        );
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

  /// Re-points one branch's destination through [remap], recursing into the
  /// branches nested inside it.
  ///
  /// A branch whose destination was dropped loses the link: that step is not
  /// being saved, so the path has to end here. Keeping the stale number would
  /// quietly redirect the path to whatever step took over the slot.
  void _remapLink(BranchInputData branch, Map<int, int> remap) {
    final target = branch.nextStepNumber;
    if (target != null) {
      final mapped = remap[target];
      if (mapped == null) {
        branch.nextStepNumber = null;
        branch.nextStepTitle = null;
      } else {
        branch.nextStepNumber = mapped;
      }
    }
    for (final sub in branch.subBranches) {
      _remapLink(sub, remap);
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
      await _local.updateLegalCase(
        id: widget.legalCase.id,
        title: title,
        description: _descController.text.trim(),
      );

      // 2. Soft delete steps the admin deleted in the editor.
      for (final id in _deletedStepIds) {
        await _local.deleteCaseStep(id: id);
      }
      _deletedStepIds.clear();

      // 3. Upsert every step in order. Existing rows are updated, steps added
      //    from the editor are inserted and keep their new ids so a second save
      //    updates them instead of duplicating.
      //
      //    A step with no title is skipped, so the survivors are renumbered to
      //    a gapless 1..n first. The path links stored inside a step point at
      //    other steps by number, so they are re-pointed through the same plan
      //    before the descriptions are re-encoded — otherwise a link picked as
      //    «to step 3» would end up on whichever stage slid into that slot.
      final keeps = _steps
          .map((s) => (s['title'] ?? '').toString().trim().isNotEmpty)
          .toList();
      final plan = renumberSteps(keeps);
      final remap = plan.remap;
      final numbers = plan.numbers;

      for (int i = 0; i < _steps.length; i++) {
        final branches =
            _stepBranches[_stepKey(_steps[i], i)] ?? <BranchInputData>[];
        for (final branch in branches) {
          _remapLink(branch, remap);
        }
      }

      var saved = 0;
      for (int i = 0; i < _steps.length; i++) {
        if (!keeps[i]) continue;

        final step = _steps[i];
        final key = _stepKey(step, i);
        final branches = _stepBranches[key] ?? <BranchInputData>[];

        final stepNumber = numbers[saved];
        saved++;

        final shortDescription = encodeStepDescription(
          stepNumber: stepNumber,
          description: (step['short_description'] ?? '').toString(),
          branches: branches,
        );
        final stepTitle = (step['title'] ?? '').toString();

        final id = step['id']?.toString();
        if (id == null || id.isEmpty) {
          final newId = await _local.insertCaseStep(
            caseId: widget.legalCase.id,
            stepNumber: stepNumber,
            title: stepTitle,
            shortDescription: shortDescription,
          );

          step['id'] = newId;
          step['step_number'] = stepNumber;

          // Re-key the branch model now that the step has a real id.
          if (key != newId) {
            _stepBranches[newId] = branches;
            _stepBranches.remove(key);
          }
        } else {
          await _local.updateCaseStep(
            id: id,
            stepNumber: stepNumber,
            title: stepTitle,
            shortDescription: shortDescription,
          );
          step['step_number'] = stepNumber;
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
        .map(
          (s) => <String, dynamic>{
            'id': null,
            'title': s.titleController.text.trim(),
            'short_description': s.descController.text.trim(),
          },
        )
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

  // صف فولدر واحد مع أيقونة تعديل وأيقونة سلة حذف بجانبها
  Widget _buildFolderRow({
    required IconData icon,
    required String label,
    required String name,
    required Color color,
  }) {
    final isCategory = label == 'الفولدر الكبير';
    final id = isCategory ? _categoryId : _subcategoryId;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_rounded,
              size: 20,
              color: Colors.blueGrey,
            ),
            tooltip: 'تعديل اسم هذا الفولدر',
            onPressed: (_isFolderSaving || id == null)
                ? null
                : () => _renameFolder(
                    id: id,
                    table: isCategory ? 'categories' : 'subcategories',
                    currentName: name,
                    isCategory: isCategory,
                  ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: Colors.redAccent,
            ),
            tooltip: 'حذف هذا الفولدر وكل ما بداخله',
            onPressed: (_isFolderSaving || id == null)
                ? null
                : () =>
                      _deleteFolder(id: id, name: name, isCategory: isCategory),
          ),
        ],
      ),
    );
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'بيانات القضية',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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

                  // مسار الفولدر: من أكبر فولدر حتى الفولدر الذي به هذه القضية
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'مسار الفولدر',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          if (_isFolderLoading)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: LinearProgressIndicator(),
                            )
                          else if (_categoryName.isEmpty &&
                              _subcategoryName.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('القضية غير مرتبطة بأي فولدر'),
                            )
                          else ...[
                            _buildFolderRow(
                              icon: Icons.folder_special_rounded,
                              label: 'الفولدر الكبير',
                              name: _categoryName,
                              color: const Color(0xFF1E3A8A),
                            ),
                            if (_subcategoryName.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.only(
                                  right: 6,
                                  top: 2,
                                  bottom: 2,
                                ),
                                child: Text(
                                  '‹',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              _buildFolderRow(
                                icon: Icons.folder_rounded,
                                label: 'الفولدر',
                                name: _subcategoryName,
                                color: Colors.amber.shade800,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Case Steps section
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'خطوات ومسار القضية',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
                              final branchCount =
                                  (_stepBranches[_stepKey(step, index)] ??
                                          <BranchInputData>[])
                                      .length;
                              return ListTile(
                                onTap: _openRoadmapEditor,
                                leading: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _removeStep(index),
                                  tooltip: 'حذف هذه الخطوة من المسار',
                                ),
                                title: Row(
                                  children: [
                                    if (step['id'] == null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.shade300,
                                          ),
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
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if ((step['short_description'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(
                                        step['short_description'] ?? '',
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (branchCount > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
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
                                icon: const Icon(
                                  Icons.account_tree_rounded,
                                  size: 18,
                                ),
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
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.6,
                                color: Colors.grey,
                              ),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
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
