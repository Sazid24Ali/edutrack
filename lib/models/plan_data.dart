import 'plan_day.dart';

class PlanData {
  String name;
  List<DayPlan> days;
  int alarmHour;
  int alarmMinute;

  PlanData({
    required this.name,
    required this.days,
    required this.alarmHour,
    required this.alarmMinute,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'alarmHour': alarmHour,
    'alarmMinute': alarmMinute,
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory PlanData.fromJson(Map<String, dynamic> json) => PlanData(
    name: json['name'],
    alarmHour: json['alarmHour'],
    alarmMinute: json['alarmMinute'],
    days: (json['days'] as List).map((d) => DayPlan.fromJson(d)).toList(),
  );
}
