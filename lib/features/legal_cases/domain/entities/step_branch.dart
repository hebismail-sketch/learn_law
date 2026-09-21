class StepBranch {
  final String title;
  final String description;
  final List<String> subSteps;

  StepBranch({
    required this.title,
    required this.description,
    this.subSteps = const [],
  });

  factory StepBranch.fromJson(Map<String, dynamic> json) {
    return StepBranch(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      subSteps: (json['sub_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'sub_steps': subSteps,
    };
  }
}
