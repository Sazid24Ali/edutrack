import 'package:edutrack/screens/planner_screen.dart';

import 'topic.dart';

class DayPlan {
  DateTime date;
  List<TopicModel> topics;
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

  factory DayPlan.fromJson(dynamic json) {
    // json might be Map or List (old formats) — handle robustly
    if (json is Map<String, dynamic>) {
      final topicsJson = (json['topics'] as List<dynamic>?) ?? <dynamic>[];
      return DayPlan(
        date:
            DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        totalMinutes: (json['totalMinutes'] ?? 0) is int
            ? json['totalMinutes']
            : (json['totalMinutes'] as num).toInt(),
        topics: topicsJson
            .map<TopicModel>((t) {
              if (t is Map<String, dynamic>) return TopicModel.fromJson(t);
              return TopicModel.fromJson(Map<String, dynamic>.from(t));
            })
            .toList()
            .cast<TopicModel>(),
      );
    } else if (json is List) {
      // old list-of-topics format -> create DayPlan with today's date
      final topics = json.map<TopicModel>((t) {
        if (t is Map<String, dynamic>) return TopicModel.fromJson(t);
        return TopicModel.fromJson(Map<String, dynamic>.from(t));
      }).toList();
      final total = topics.fold<int>(0, (s, t) => s + t.estimatedMinutes);
      return DayPlan(date: DateTime.now(), topics: topics, totalMinutes: total);
    } else {
      // fallback
      return DayPlan(date: DateTime.now(), topics: [], totalMinutes: 0);
    }
  }
}
