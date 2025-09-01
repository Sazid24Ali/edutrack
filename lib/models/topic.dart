class Topic {
  String name;
  int estimatedMinutes;

  Topic({required this.name, required this.estimatedMinutes});

  Map<String, dynamic> toJson() => {
    'name': name,
    'estimatedMinutes': estimatedMinutes,
  };

  factory Topic.fromJson(Map<String, dynamic> json) =>
      Topic(name: json['name'], estimatedMinutes: json['estimatedMinutes']);
}
