class StepBranch {
  final String title;
  final String description;
  final List<String> subSteps;
  final String? outcome; // 'acceptance', 'rejection', 'appeal', 'custom'
  final List<StepBranch> branches;

  StepBranch({
    required this.title,
    required this.description,
    this.subSteps = const [],
    this.outcome,
    this.branches = const [],
  });

  factory StepBranch.fromJson(Map<String, dynamic> json) {
    List<StepBranch> childBranches = [];
    if (json['branches'] is List) {
      childBranches = (json['branches'] as List)
          .map((b) => StepBranch.fromJson(Map<String, dynamic>.from(b)))
          .toList();
    }

    return StepBranch(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      outcome: json['outcome'],
      subSteps: (json['sub_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      branches: childBranches,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'sub_steps': subSteps,
      if (outcome != null) 'outcome': outcome,
      if (branches.isNotEmpty)
        'branches': branches.map((b) => b.toJson()).toList(),
    };
  }
}

