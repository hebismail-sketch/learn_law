import 'dart:convert';

import 'package:flutter/material.dart';


class BranchKind {
  final String id;
  final String defaultTitle;
  final IconData icon;
  final Color color;
  final String hint;

  const BranchKind({
    required this.id,
    required this.defaultTitle,
    required this.icon,
    required this.color,
    required this.hint,
  });
}

const List<BranchKind> kBranchKinds = [
  BranchKind(
    id: 'acceptance',
    defaultTitle: 'قبول',
    icon: Icons.check_circle_rounded,
    color: Color(0xFF10B981),
    hint: 'المسار الذي يتم فيه القبول والتنفيذ',
  ),
  BranchKind(
    id: 'rejection',
    defaultTitle: 'رفض',
    icon: Icons.cancel_rounded,
    color: Color(0xFFEF4444),
    hint: 'المسار الذي يتم فيه رفض الطلب أو الدعوى',
  ),
  BranchKind(
    id: 'appeal',
    defaultTitle: 'طور ثاني',
    icon: Icons.gavel_rounded,
    color: Color(0xFFF59E0B),
    hint: 'مسار الطعن / الاستئناف / الطور الثاني',
  ),
  BranchKind(
    id: 'custom',
    defaultTitle: 'فرع أخر',
    icon: Icons.alt_route_rounded,
    color: Color(0xFF6366F1),
    hint: 'أي مسار مخصص أخر تكتبه بنفسك',
  ),
];

Color branchColorFor(String? outcome) {
  for (final k in kBranchKinds) {
    if (k.id == outcome) return k.color;
  }
  return kBranchKinds.last.color; // custom
}

BranchKind branchKindFor(String? outcome) {
  for (final k in kBranchKinds) {
    if (k.id == outcome) return k;
  }
  return kBranchKinds.last;
}

/// Detect the outcome id from a free-text title (used when importing legacy
/// data that only had a title and no structured `outcome` field).
String? inferOutcomeFromTitle(String title) {
  if (title.contains('قبول')) return 'acceptance';
  if (title.contains('رفض')) return 'rejection';
  if (title.contains('طعن') || title.contains('استئناف') || title.contains('طور')) {
    return 'appeal';
  }
  return null;
}

/// ============================================================================
/// Input data models (mutable, controller-backed)
/// ============================================================================

class StepInputData {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final List<BranchInputData> branches = [];

  StepInputData({String? title, String? desc}) {
    if (title != null) titleController.text = title;
    if (desc != null) descController.text = desc;
  }

  void addBranch({BranchInputData? branch}) {
    branches.add(branch ?? BranchInputData());
  }

  void removeBranch(int index) {
    if (index >= 0 && index < branches.length) {
      final b = branches.removeAt(index);
      _disposeLater(b);
    }
  }

  bool get isEmptyText =>
      titleController.text.trim().isEmpty &&
      descController.text.trim().isEmpty &&
      branches.isEmpty;

  void dispose() {
    titleController.dispose();
    descController.dispose();
    for (final b in branches) {
      b.dispose();
    }
  }
}

class BranchInputData {
  final TextEditingController titleController;
  final TextEditingController descController = TextEditingController();
  String? outcome;
  final List<TextEditingController> subStepControllers = [];
  final List<BranchInputData> subBranches = [];

  /// Link to the next main step this path continues to (1-based step_number).
  /// When set, the admin chose «الانتقال للخطوة التالية» for this path instead
  /// of ending it here. It is scoped to the step that owns this branch and is
  /// only serialized on top-level branches (see [encodeStepDescription]).
  int? nextStepNumber;

  /// Snapshot of the target step's title, kept only so the admin can see where
  /// this path leads before saving (the real title lives in `case_steps`).
  String? nextStepTitle;

  BranchInputData({String? defaultTitle, this.outcome})
      : titleController = TextEditingController(text: defaultTitle ?? '');

  Color get color => branchColorFor(outcome);

  void addSubStep([String text = '']) {
    subStepControllers.add(TextEditingController(text: text));
  }

  void removeSubStep(int index) {
    if (index >= 0 && index < subStepControllers.length) {
      final ctrl = subStepControllers.removeAt(index);
      _disposeLater(ctrl);
    }
  }

  void addSubBranch({String? defaultTitle, String? branchOutcome}) {
    subBranches.add(BranchInputData(
      defaultTitle: defaultTitle,
      outcome: branchOutcome,
    ));
  }

  void removeSubBranch(int index) {
    if (index >= 0 && index < subBranches.length) {
      final b = subBranches.removeAt(index);
      _disposeLater(b);
    }
  }

  void dispose() {
    titleController.dispose();
    descController.dispose();
    for (final c in subStepControllers) {
      c.dispose();
    }
    for (final b in subBranches) {
      b.dispose();
    }
  }
}

void _disposeLater(Object obj) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (obj is BranchInputData) obj.dispose();
    if (obj is TextEditingController) obj.dispose();
  });
}

/// Deep-clone a branch (and everything nested under it) into fresh controllers.
/// This decouples widget lifetimes: an editor can be disposed without
/// invalidating the model held by another screen.
BranchInputData cloneBranch(BranchInputData b) {
  final clone = BranchInputData(
    defaultTitle: b.titleController.text,
    outcome: b.outcome,
  );
  clone.descController.text = b.descController.text;
  clone.nextStepNumber = b.nextStepNumber;
  clone.nextStepTitle = b.nextStepTitle;

  for (final s in b.subStepControllers) {
    clone.addSubStep(s.text);
  }
  for (final sb in b.subBranches) {
    clone.subBranches.add(cloneBranch(sb));
  }
  return clone;
}

/// ============================================================================
/// Serialization
/// ============================================================================

/// Convert one branch (and everything nested under it) to the JSON shape
/// consumed by `StepBranch.fromJson`.
Map<String, dynamic> branchToJson(BranchInputData b) {
  final desc = b.descController.text.trim();

  List<String> subSteps = b.subStepControllers
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  final validSubBranches = b.subBranches
      .where((sb) => sb.titleController.text.trim().isNotEmpty)
      .map(branchToJson)
      .toList();

  return {
    'title': b.titleController.text.trim(),
    'description': desc,
    'sub_steps': subSteps,
    if (b.outcome != null) 'outcome': b.outcome,
    if (validSubBranches.isNotEmpty) 'branches': validSubBranches,
  };
}

/// Build the final `short_description` string for a step, encoding its
/// branches when present (prefix + JSON), or the plain description otherwise.
String encodeStepDescription({
  required String description,
  required List<BranchInputData> branches,
  int? stepNumber,
}) {
  final valid = branches
      .where((b) => b.titleController.text.trim().isNotEmpty)
      .map(branchToJson)
      .toList();

  if (valid.isEmpty) return description;

  // Path links (`next_step`) point at other rows of `case_steps` by their
  // `step_number`, so they are only meaningful on top-level branches — the
  // only place the admin can pick a destination step from the editor.
  final links = <Map<String, dynamic>>[];
  for (int i = 0; i < branches.length; i++) {
    final b = branches[i];
    if (b.titleController.text.trim().isEmpty) continue;
    if (b.nextStepNumber == null) continue;
    links.add({
      'step_title': b.titleController.text.trim(),
      'next_step': b.nextStepNumber,
      if (b.nextStepTitle != null && b.nextStepTitle!.trim().isNotEmpty)
        'next_step_title': b.nextStepTitle!.trim(),
    });
  }

  return '__BRANCHES_JSON__${jsonEncode({
        'step_number': ?stepNumber,
        'main_description': description,
        'branches': valid,
        if (links.isNotEmpty) 'path_links': links,
      })}';
}

/// Decode a stored step row back into input models (used by the edit screen).
({String description, List<BranchInputData> branches}) decodeStepDescription(
  String raw,
) {
  var desc = raw;
  final branches = <BranchInputData>[];

  if (raw.startsWith('__BRANCHES_JSON__')) {
    try {
      final map = jsonDecode(raw.replaceFirst('__BRANCHES_JSON__', ''));
      desc = (map['main_description'] ?? '').toString();
      final list = map['branches'] as List<dynamic>?;
      if (list != null) {
        for (final raw in list) {
          branches.add(_branchFromJson(Map<String, dynamic>.from(raw)));
        }
      }

      // Re-apply saved path links onto the top-level branches (matched by
      // title, so an admin who renamed a branch keeps its link intact).
      final links = map['path_links'] as List<dynamic>?;
      if (links != null) {
        for (final raw in links) {
          final link = Map<String, dynamic>.from(raw);
          final title = (link['step_title'] ?? '').toString();

          for (final b in branches) {
            if (b.titleController.text.trim() != title) continue;
            final next = link['next_step'];
            b.nextStepNumber = next is int ? next : int.tryParse('$next');
            b.nextStepTitle = link['next_step_title']?.toString();
            break;
          }
        }
      }
    } catch (_) {
      desc = raw;
    }
  }

  return (description: desc, branches: branches);
}

BranchInputData _branchFromJson(Map<String, dynamic> json) {
  final title = (json['title'] ?? '').toString();
  final outcome = (json['outcome'] ?? inferOutcomeFromTitle(title))?.toString();

  final branch = BranchInputData(defaultTitle: title, outcome: outcome);
  branch.descController.text = (json['description'] ?? '').toString();

  final subs = json['sub_steps'] as List<dynamic>?;
  if (subs != null) {
    for (final s in subs) {
      branch.addSubStep(s.toString());
    }
  }

  final children = json['branches'] as List<dynamic>?;
  if (children != null) {
    for (final c in children) {
      branch.subBranches.add(_branchFromJson(Map<String, dynamic>.from(c)));
    }
  }

  return branch;
}

/// A step the admin can send a path to, as offered by [showNextStepPicker].
class NextStepChoice {
  final int number;
  final String title;

  const NextStepChoice({required this.number, required this.title});
}

/// Picker for «الانتقال للخطوة التالية»: lists the steps *after* [fromIndex]
/// (the natural "next" for a path that just reached an outcome), plus the step
/// itself so the admin can loop a path back into it if the case needs that.
Future<NextStepChoice?> showNextStepPicker(
  BuildContext context, {
  required List<StepInputData> steps,
  required int fromIndex,
}) {
  // Only steps that actually carry a title can be a destination.
  final choices = <NextStepChoice>[];
  for (int i = 0; i < steps.length; i++) {
    final title = steps[i].titleController.text.trim();
    if (title.isEmpty) continue;
    final isSelf = i == fromIndex;
    choices.add(NextStepChoice(
      number: i + 1,
      title: isSelf ? '$title (هذه الخطوة نفسها)' : title,
    ));
  }

  return showDialog<NextStepChoice>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('الانتقال للخطوة التالية', textAlign: TextAlign.right),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: double.maxFinite,
          child: choices.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'لا توجد خطوات مسمّاة بعد. أضف خطوة رئيسية جديدة أولاً.',
                    textAlign: TextAlign.right,
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: choices.map((c) {
                    return ListTile(
                      onTap: () => Navigator.pop(ctx, c),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF1E3A8A),
                        child: Text(
                          '${c.number}',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      title: Text(
                        c.title,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    ),
  );
}

/// ============================================================================
/// 1) Branch picker dialog — the single entry point for "add a branch".
/// ============================================================================

Future<BranchKind?> showBranchKindPicker(BuildContext context) {
  return showDialog<BranchKind>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('اختر نوع الفرع', textAlign: TextAlign.right),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: kBranchKinds.map((kind) {
              return ListTile(
                onTap: () => Navigator.pop(ctx, kind),
                leading: CircleAvatar(
                  backgroundColor: kind.color.withValues(alpha: 0.15),
                  child: Icon(kind.icon, color: kind.color, size: 20),
                ),
                title: Text(
                  kind.defaultTitle,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  kind.hint,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11.5),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    ),
  );
}

/// ============================================================================
/// 2) The tree editor widget.
/// ============================================================================

class RoadmapEditor extends StatefulWidget {
  final List<StepInputData> steps;
  final VoidCallback onAddStep;
  final void Function(int index) onRemoveStep;

  /// Called when the admin asks for a branch on the *path* (i.e. right under a
  /// step, next to the previous branch), as opposed to inside an existing
  /// branch. When omitted the button is hidden — the step-level «إضافة فرع»
  /// button covers that case on its own.
  final void Function(int stepIndex)? onAddPathBranch;

  /// Called for structural changes (add/remove) so the parent can refresh
  /// anything derived from the tree (e.g. a preview). Not called on typing.
  final VoidCallback? onChanged;

  const RoadmapEditor({
    super.key,
    required this.steps,
    required this.onAddStep,
    required this.onRemoveStep,
    this.onAddPathBranch,
    this.onChanged,
  });

  @override
  State<RoadmapEditor> createState() => _RoadmapEditorState();
}

class _RoadmapEditorState extends State<RoadmapEditor> {
  /// Links a rendered branch card back to its parent container, so the card can
  /// add sub-branches and remove itself without relying on closure captures of
  /// the (re-created every build) `steps` element list.
  static final Expando<_BranchHost> _hosts = Expando<_BranchHost>();

  // Structural changes rebuild locally so typing on a slow device stays smooth,
  // and the (heavy) preview is not rebuilt on every keystroke.
  void _mutate(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
  }

  /// One shared entry point for "add a branch": pick a kind, then attach it.
  Future<void> _addBranchWithPicker({
    required BranchInputData? parent,
    required StepInputData? step,
  }) async {
    final kind = await showBranchKindPicker(context);
    if (kind == null || !mounted) return;

    _mutate(() {
      final branch = BranchInputData(
        defaultTitle: kind.defaultTitle,
        outcome: kind.id,
      );
      if (parent != null) {
        parent.subBranches.add(branch);
      } else if (step != null) {
        step.branches.add(branch);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intro(context),
        const SizedBox(height: 8),
        ...List.generate(widget.steps.length, (i) => _buildStepCard(context, i)),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _mutate(widget.onAddStep),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة خطوة رئيسية جديدة'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _intro(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'ابدأ بالخطوة الرئيسية (مثال: مقابلة الموكل وتجهيز المستندات). '
              'ثم اضغط «إضافة فرع» وأختر النوع: قبول أو رفض أو طور ثاني أو فرع أخر. '
              'داخل كل فرع يمكنك إضافة محطاته المتتالية على الجانب، '
              'أو التفرع داخله من جديد بنفس الطريقة.',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF1E3A8A)),
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.account_tree_rounded, color: Color(0xFF1D4ED8)),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Main step card
  // --------------------------------------------------------------------------
  Widget _buildStepCard(BuildContext context, int index) {
    final step = widget.steps[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.steps.length > 1)
                IconButton(
                  tooltip: 'حذف الخطوة',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () => _mutate(() => widget.onRemoveStep(index)),
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Text(
                  'الخطوة الرئيسية (${index + 1})',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF1E3A8A),
                child: Icon(Icons.timeline_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: step.titleController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'عنوان الخطوة',
              hintText: 'مثال: مقابلة الموكل وتجهيز المستندات',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: step.descController,
            textAlign: TextAlign.right,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'تفاصيل الخطوة (اختياري)',
              hintText: 'الشروط، الأوراق المطلوبة، ملاحظات..',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Branches header + add button
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _addBranchWithPicker(step: step, parent: null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة فرع'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'فروع هذه الخطوة (${step.branches.length})',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const Icon(Icons.call_split_rounded, size: 18, color: Color(0xFF64748B)),
            ],
          ),

          if (step.branches.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'لا توجد فروع بعد لهذه الخطوة. اضغط «إضافة فرع» لإضافة قبول أو رفض..',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
            )
          else
            for (int b = 0; b < step.branches.length; b++)
              _buildBranchCard(
                context,
                step.branches[b],
                depth: 0,
                branchNumber: b + 1,
                parent: step,
                stepIndex: index,
                siblings: step.branches,
              ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Recursive branch card
  // --------------------------------------------------------------------------
  Widget _buildBranchCard(
    BuildContext context,
    BranchInputData branch, {
    required int depth,
    required int branchNumber,

    /// Container this branch lives in: a [StepInputData] for top-level branches
    /// or another [BranchInputData] for nested ones.
    required Object parent,

    /// Index of the owning step in [RoadmapEditor.steps]; only used to look up
    /// the following step for the «الانتقال للخطوة التالية» button.
    required int stepIndex,

    /// Branches rendered next to this one on the same path (used to append the
    /// new branch "بعدها" — right after its sibling).
    required List<BranchInputData> siblings,
  }) {
    final accent = branch.color;
    final kind = branchKindFor(branch.outcome);

    _hosts[branch] = _BranchHost(stepIndex: stepIndex, parent: parent, siblings: siblings);

    return Container(
      margin: EdgeInsets.only(top: 12, right: depth * 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colored header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'حذف الفرع',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 20),
                  onPressed: () => _removeBranch(branch),
                ),
                Expanded(
                  child: Text(
                    depth == 0 ? 'فرع: ${kind.defaultTitle}' : 'فرع تابع',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accent,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(kind.icon, color: accent, size: 18),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title + outcome chips
                TextField(
                  controller: branch.titleController,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'عنوان الفرع',
                    hintText: 'مثال: في حالة القبول',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: kBranchKinds.map((k) {
                    final selected = branch.outcome == k.id;
                    return ChoiceChip(
                      label: Text(k.defaultTitle),
                      selected: selected,
                      onSelected: (_) => _mutate(() {
                        branch.outcome = k.id;
                      }),
                      avatar: Icon(
                        k.icon,
                        size: 16,
                        color: selected ? Colors.white : k.color,
                      ),
                      selectedColor: k.color,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : k.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      backgroundColor: k.color.withValues(alpha: 0.08),
                      side: BorderSide(color: k.color.withValues(alpha: 0.4)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: branch.descController,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'وصف عام لهذا الفرع ونتيجته (اختياري)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                // Stations (linear chain inside this branch)
                _buildStationsEditor(branch, accent),

                const SizedBox(height: 10),

                // Nested sub-branches
                _buildSubBranchesEditor(context, branch, accent, depth, branchNumber),

                // A fork is rarely the end of the story: let the admin add
                // another branch on the *same* path right after this one, and
                // (for a top-level branch) continue this path to the next step.
                if (depth == 0) ...[
                  const SizedBox(height: 10),
                  _buildNextStepControl(branch, accent),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationsEditor(BranchInputData branch, Color accent) {
    final count = branch.subStepControllers.length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _mutate(() => branch.addSubStep()),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('إضافة محطة (خطوة في المسار)',
                    style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'محطات الفرع ($count)',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Icon(Icons.timeline_rounded, size: 16, color: Color(0xFF3B82F6)),
            ],
          ),
          if (count == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'لا توجد محطات بعد. هذه الخطوات المتتالية التي تظهر على الجانب في خريطة الطريق.',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            )
          else
            for (int s = 0; s < count; s++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'حذف المحطة',
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          color: Colors.redAccent, size: 18),
                      onPressed: () => _mutate(() => branch.removeSubStep(s)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: branch.subStepControllers[s],
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'المحطة ${s + 1} في هذا المسار',
                          hintText: 'الإجراء الذي يلي المحطة السابقة مباشرة',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: accent.withValues(alpha: 0.2),
                      child: Text(
                        '${s + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildSubBranchesEditor(
    BuildContext context,
    BranchInputData branch,
    Color accent,
    int depth,
    int branchNumber,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _addBranchWithPicker(parent: branch, step: null),
                icon: Icon(Icons.schema_rounded, size: 16, color: accent),
                label: Text(
                  'إضافة فرع داخل هذا الفرع',
                  style: TextStyle(fontSize: 12, color: accent),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'أفرع تفرعت من هذا الفرع (${branch.subBranches.length})',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
              Icon(Icons.account_tree_rounded, size: 18, color: accent),
            ],
          ),
          if (branch.subBranches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'اتركه فرعاً نهائياً، أو تفرع داخله (مثال: رفض ← طعن ← قبول الطعن).',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            )
          else
            for (int sb = 0; sb < branch.subBranches.length; sb++)
              _buildBranchCard(
                context,
                branch.subBranches[sb],
                depth: depth + 1,
                branchNumber: 1,
                parent: branch,
                stepIndex: _hosts[branch]?.stepIndex ?? 0,
                siblings: branch.subBranches,
              ),

          // The link itself: this branch discovered its own outcome, so the
          // admin can fork the path again right after it ("إضافة تفريع لهذا
          // المسار") and, on a top-level branch, send the path to the next
          // main step ("الانتقال للخطوة التالية").
          if (depth == 0) _buildPathActions(context, branch, accent),
        ],
      ),
    );
  }

  /// Builds the two path-level actions shown under a top-level branch:
  /// adding a sibling branch to the same path, and moving to the next step.
  Widget _buildPathActions(
    BuildContext context,
    BranchInputData branch,
    Color accent,
  ) {
    final stepIndex = _hosts[branch]?.stepIndex ?? 0;
    final hasNextStep = stepIndex + 1 < widget.steps.length;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'مسار هذا الفرع',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
              Icon(Icons.route_rounded, size: 18, color: accent),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              // «إضافة تفريع لهذا المسار» — appends another branch right after
              // this one, on the same path.
              OutlinedButton.icon(
                onPressed: () {
                  final host = _hosts[branch];
                  // Siblings belong to the same container as this branch, so the
                  // new branch lands next to it on the same path.
                  _addBranchWithPicker(
                    parent: host?.parent is BranchInputData
                        ? host!.parent as BranchInputData
                        : null,
                    step: host?.parent is StepInputData
                        ? host!.parent as StepInputData
                        : null,
                  );
                },
                icon: Icon(Icons.alt_route_rounded, size: 16, color: accent),
                label: Text(
                  'إضافة تفريع لهذا المسار',
                  style: TextStyle(fontSize: 12, color: accent),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
              // «الانتقال للخطوة التالية» — link this path to the next step.
              FilledButton.tonalIcon(
                onPressed: () => _goToNextStep(branch),
                icon: Icon(
                  branch.nextStepNumber != null
                      ? Icons.link_off_rounded
                      : Icons.skip_next_rounded,
                  size: 16,
                ),
                label: Text(
                  branch.nextStepNumber != null
                      ? 'إلغاء الانتقال للخطوة التالية'
                      : 'الانتقال للخطوة التالية',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (branch.nextStepNumber != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'هذا المسار ينتقل إلى الخطوة رقم (${branch.nextStepNumber})'
                      '${branch.nextStepTitle != null && branch.nextStepTitle!.isNotEmpty ? ': ${branch.nextStepTitle}' : ''}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_downward_rounded,
                      size: 16, color: Color(0xFF0F766E)),
                ],
              ),
            )
          else if (!hasNextStep)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'لا توجد خطوة تالية بعد. أضف «خطوة رئيسية جديدة» أسفل المحرر ثم اضغط هذا الزر لربط المسار بها.',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  /// Small banner under the branch description showing where its path leads,
  /// mirroring what the admin sees in the app roadmap.
  Widget _buildNextStepControl(BranchInputData branch, Color accent) {
    if (branch.nextStepNumber == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.call_merge_rounded, size: 16, color: Color(0xFF047857)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'يندمج مع الخطوة رقم (${branch.nextStepNumber})',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the destination picker and stores the choice on the branch.
  Future<void> _goToNextStep(BranchInputData branch) async {
    if (branch.nextStepNumber != null) {
      _mutate(() {
        branch.nextStepNumber = null;
        branch.nextStepTitle = null;
      });
      return;
    }

    final stepIndex = _hosts[branch]?.stepIndex ?? 0;
    final target = await showNextStepPicker(
      context,
      steps: widget.steps,
      fromIndex: stepIndex,
    );
    if (target == null || !mounted) return;

    _mutate(() {
      branch.nextStepNumber = target.number;
      branch.nextStepTitle = target.title;
    });
  }

  /// Removes a branch from whichever container owns it.
  void _removeBranch(BranchInputData branch) {
    final host = _hosts[branch];
    if (host == null) return;

    _mutate(() {
      if (host.parent is StepInputData) {
        (host.parent as StepInputData).branches.remove(branch);
      } else if (host.parent is BranchInputData) {
        (host.parent as BranchInputData).subBranches.remove(branch);
      }
    });
  }
}

/// Identifies the container a rendered branch card belongs to.
class _BranchHost {
  final int stepIndex;
  final Object parent;
  final List<BranchInputData> siblings;

  const _BranchHost({
    required this.stepIndex,
    required this.parent,
    required this.siblings,
  });
}

/// ============================================================================
/// 3) Live preview of the resulting roadmap tree (so the admin sees the shape
///    before saving).
/// ============================================================================

class RoadmapPreview extends StatelessWidget {
  final List<StepInputData> steps;

  const RoadmapPreview({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final filled = steps
        .where((s) => s.titleController.text.trim().isNotEmpty)
        .toList();

    if (filled.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'ستظهر هنا معاينة الشكل النهائي بمجرد كتابة أول خطوة.',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(filled.length, (i) {
        return _previewStep(filled[i], i + 1);
      }),
    );
  }

  Widget _previewStep(StepInputData step, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _previewNode(
          title: step.titleController.text.trim().isEmpty
              ? 'خطوة $index'
              : step.titleController.text.trim(),
          color: const Color(0xFF1E3A8A),
          icon: Icons.timeline_rounded,
          isRoot: true,
        ),
        if (step.branches.isNotEmpty) ...[
          _forkLine(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final b in step.branches)
                Expanded(child: _previewBranch(b)),
            ],
          ),
          _mergeLine(),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.arrow_downward_rounded,
                color: Color(0xFF94A3B8), size: 18),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _previewBranch(BranchInputData branch) {
    final accent = branch.color;
    final stations = branch.subStepControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _previewNode(
            title: branch.titleController.text.trim().isEmpty
                ? 'فرع'
                : branch.titleController.text.trim(),
            color: accent,
            icon: branchKindFor(branch.outcome).icon,
            isRoot: false,
          ),
          if (stations.isEmpty && branch.subBranches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '—',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          for (final s in stations) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Icon(Icons.more_vert_rounded,
                  size: 14, color: Color(0xFF94A3B8)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Text(
                s,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
          for (final sb in branch.subBranches) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.subdirectory_arrow_left_rounded,
                      size: 12, color: Color(0xFF94A3B8)),
                  SizedBox(width: 4),
                  Text('تفرع داخل الفرع', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            _previewBranch(sb),
          ],
        ],
      ),
    );
  }

  Widget _previewNode({
    required String title,
    required Color color,
    required IconData icon,
    required bool isRoot,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: isRoot ? 10 : 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: isRoot ? 16 : 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isRoot ? 12.5 : 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _forkLine() {
    return const Padding(
      padding: EdgeInsets.only(top: 6, bottom: 6),
      child: Icon(Icons.account_tree_rounded, color: Color(0xFF94A3B8), size: 18),
    );
  }

  Widget _mergeLine() {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Icon(Icons.arrow_downward_rounded, color: Color(0xFF94A3B8), size: 18),
    );
  }
}
