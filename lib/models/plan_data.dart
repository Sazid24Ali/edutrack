// lib/models/plan_data.dart
import 'plan_day.dart';

class PlanData {
  String name;
  List<DayPlan> days;
  int alarmHour;
  int alarmMinute;

  PlanData({
    required this.name,
    required this.days,
    this.alarmHour = 8,
    this.alarmMinute = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'days': days.map((d) => d.toJson()).toList(),
    'alarmHour': alarmHour,
    'alarmMinute': alarmMinute,
  };

  factory PlanData.fromJson(Map<String, dynamic> json) => PlanData(
    name: json['name'],
    days: (json['days'] as List<dynamic>)
        .map((d) => DayPlan.fromJson(d))
        .toList(),
    alarmHour: json['alarmHour'] ?? 8,
    alarmMinute: json['alarmMinute'] ?? 0,
  );
}
