import 'topic.dart';

class DayPlan {
  DateTime date;
  List<Topic> topics;
  int totalMinutes;

  DayPlan({
    required this.date,
    required this.topics,
    required this.totalMinutes,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'totalMinutes': totalMinutes,
    'topics': topics.map((t) => t.toJson()).toList(),
  };

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
    date: DateTime.parse(json['date']),
    totalMinutes: json['totalMinutes'],
    topics: (json['topics'] as List).map((t) => Topic.fromJson(t)).toList(),
  );
}
