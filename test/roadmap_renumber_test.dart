import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/features/legal_cases/presentation/widgets/roadmap_editor.dart';

/// A branch carrying only what [remapBranchLinks] reads.
BranchInputData _branch({int? nextStepNumber}) {
  final b = BranchInputData(defaultTitle: 'فرع');
  b.nextStepNumber = nextStepNumber;
  b.nextStepTitle = nextStepNumber == null ? null : 'خطوة $nextStepNumber';
  return b;
}

StepInputData _step(List<BranchInputData> branches) =>
    StepInputData()..branches.addAll(branches);

void main() {
  group('renumberSteps', () {
    test('assigns a gapless 1..n to the steps that are kept', () {
      final plan = renumberSteps([true, true, true]);
      expect(plan.numbers, [1, 2, 3]);
      expect(plan.remap, {1: 1, 2: 2, 3: 3});
    });

    test('closes the hole left by a step that is not saved', () {
      // Editor positions 1 and 3 have titles; 2 is empty and never written.
      final plan = renumberSteps([true, false, true]);
      expect(plan.numbers, [1, 2]);
      expect(plan.remap, {1: 1, 3: 2});
    });

    test('drops the destination of a step that is not saved', () {
      final plan = renumberSteps([true, false, true]);
      // No entry for 2, so a link aimed at it has nowhere to go.
      expect(plan.remap.containsKey(2), isFalse);
    });

    test('numbers nothing when no step has a title', () {
      final plan = renumberSteps([false, false]);
      expect(plan.numbers, isEmpty);
      expect(plan.remap, isEmpty);
    });
  });

  group('remapBranchLinks', () {
    test('moves a link to the stage that took over its number', () {
      // Link said "step 3"; step 2 was dropped, so old 3 is now step 2.
      final steps = [
        _step([_branch(nextStepNumber: 3)]),
      ];

      remapBranchLinks(steps, renumberSteps([true, false, true]).remap);

      expect(steps.single.branches.single.nextStepNumber, 2);
    });

    test('clears a link whose destination is not being saved', () {
      // Link aimed at step 2, the empty step that is dropped.
      final steps = [
        _step([_branch(nextStepNumber: 2)]),
      ];

      remapBranchLinks(steps, renumberSteps([true, false, true]).remap);

      expect(steps.single.branches.single.nextStepNumber, isNull);
      expect(steps.single.branches.single.nextStepTitle, isNull);
    });

    test('leaves a branch with no link alone', () {
      final steps = [
        _step([_branch()]),
      ];

      remapBranchLinks(steps, renumberSteps([true, false, true]).remap);

      expect(steps.single.branches.single.nextStepNumber, isNull);
    });

    test('reaches a branch nested inside another branch', () {
      final nested = _branch(nextStepNumber: 3);
      final outer = _branch();
      outer.subBranches.add(nested);
      final steps = [
        _step([outer]),
      ];

      remapBranchLinks(steps, renumberSteps([true, false, true]).remap);

      expect(nested.nextStepNumber, 2);
    });

    test('re-points the links of every step in the roadmap', () {
      final steps = [
        _step([_branch(nextStepNumber: 3)]),
        _step([]),
        _step([_branch(nextStepNumber: 2)]),
      ];

      remapBranchLinks(steps, renumberSteps([true, false, true]).remap);

      // Step 1's path continues onto old step 3, renumbered to 2.
      expect(steps[0].branches.single.nextStepNumber, 2);
      // Step 3's own path pointed at the dropped step 2 and simply ends.
      expect(steps[2].branches.single.nextStepNumber, isNull);
    });
  });
}
