import 'dart:convert';

import 'package:edutrack/screens/planner_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'planning_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;

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
    topics: (json['topics'] as List<dynamic>)
        .map((t) => Topic.fromJson(t))
        .toList(),
  );
}

class PlanPreviewScreen extends StatefulWidget {
  final List<Topic> topics;
  final DateTime startDate;
  final int numDays;
  final int? dailyLimitMinutes;

  const PlanPreviewScreen({
    super.key,
    required this.topics,
    required this.startDate,
    required this.numDays,
    this.dailyLimitMinutes,
  });

  @override
  State<PlanPreviewScreen> createState() => _PlanPreviewScreenState();
}

class _PlanPreviewScreenState extends State<PlanPreviewScreen> {
  List<DayPlan> dayPlans = [];

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    tzData.initializeTimeZones();
    _generateDailyPlan();
  }

  void _generateDailyPlan() {
    List<Topic> remainingTopics = widget.topics
        .map((t) => Topic(name: t.name, estimatedMinutes: t.estimatedMinutes))
        .toList();

    int totalMinutes = remainingTopics.fold(
      0,
      (sum, t) => sum + t.estimatedMinutes,
    );
    int perDay =
        widget.dailyLimitMinutes ?? (totalMinutes / widget.numDays).ceil();

    dayPlans.clear();
    DateTime currentDate = widget.startDate;

    for (int day = 0; day < widget.numDays; day++) {
      List<Topic> dayTopics = [];
      int dayTotal = 0;

      while (remainingTopics.isNotEmpty) {
        final t = remainingTopics.first;
        if (dayTotal + t.estimatedMinutes <= perDay) {
          dayTopics.add(t);
          dayTotal += t.estimatedMinutes;
          remainingTopics.removeAt(0);
        } else {
          dayTopics.add(t);
          dayTotal += t.estimatedMinutes;
          remainingTopics.removeAt(0);
          break;
        }
      }

      dayPlans.add(
        DayPlan(date: currentDate, topics: dayTopics, totalMinutes: dayTotal),
      );
      currentDate = currentDate.add(const Duration(days: 1));
      if (remainingTopics.isEmpty) break;
    }
  }

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Future<void> _savePlan() async {
    bool setAlarm = false;
    TimeOfDay alarmTime = const TimeOfDay(hour: 8, minute: 0);

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Set Daily Alarm?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Enable daily alarm'),
                    value: setAlarm,
                    onChanged: (val) {
                      setStateDialog(() {
                        setAlarm = val;
                      });
                    },
                  ),
                  ListTile(
                    title: const Text('Alarm Time'),
                    trailing: Text('${alarmTime.format(context)}'),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: alarmTime,
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          alarmTime = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (setAlarm) {
      const androidDetails = AndroidNotificationDetails(
        'daily_plan_channel',
        'Daily Plan',
        channelDescription: 'Daily study plan reminder',
        importance: Importance.max,
        priority: Priority.high,
      );
      const platformDetails = NotificationDetails(android: androidDetails);

      for (var i = 0; i < dayPlans.length; i++) {
        final plan = dayPlans[i];
        final tzDate = tz.TZDateTime.from(
          plan.date,
          tz.local,
        ).add(Duration(hours: alarmTime.hour, minutes: alarmTime.minute));
        await flutterLocalNotificationsPlugin.zonedSchedule(
          i, // unique id
          'Study Plan Reminder',
          'Check your topics for today',
          tzDate,
          platformDetails,
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final savedPlansJson = prefs.getStringList('savedPlans') ?? [];

      // Convert current plan to JSON
      final planJson = jsonEncode(
        dayPlans
            .map(
              (d) => {
                'date': d.date.toIso8601String(),
                'totalMinutes': d.totalMinutes,
                'topics': d.topics
                    .map(
                      (t) => {
                        'name': t.name,
                        'estimatedMinutes': t.estimatedMinutes,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      );

      savedPlansJson.add(planJson);
      await prefs.setStringList('savedPlans', savedPlansJson);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan saved successfully!')));

      // Navigate to PlannerScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PlannerScreen()),
      );
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Plan saved successfully!')));
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    int totalPlannedMinutes = dayPlans.fold(
      0,
      (sum, d) => sum + d.totalMinutes,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Plan Preview')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: const Text('Total Study Time'),
                subtitle: Text(formatMinutes(totalPlannedMinutes)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: dayPlans.length,
                itemBuilder: (context, index) {
                  final day = dayPlans[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      title: Text(
                        'Day ${index + 1} - ${dateFormat.format(day.date)} (${formatMinutes(day.totalMinutes)})',
                      ),
                      children: day.topics.map((t) {
                        return ListTile(
                          title: Text(t.name),
                          subtitle: Text(formatMinutes(t.estimatedMinutes)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                day.topics.remove(t);
                                day.totalMinutes = day.topics.fold(
                                  0,
                                  (sum, t) => sum + t.estimatedMinutes,
                                );
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _savePlan,
              child: const Text('Save Plan & Set Alarm'),
            ),
          ],
        ),
      ),
    );
  }
}
