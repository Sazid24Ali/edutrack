class Topic {
  String name;
  int estimatedMinutes;
  bool completed;

  Topic({
    required this.name,
    required this.estimatedMinutes,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'estimatedMinutes': estimatedMinutes,
    'completed': completed,
  };

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
    name: json['name'],
    estimatedMinutes: json['estimatedMinutes'],
    completed: json['completed'] ?? false,
  );
}
