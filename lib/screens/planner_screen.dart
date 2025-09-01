// lib/screens/planner_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edutrack/models/plan_data.dart';
import 'package:edutrack/models/plan_day.dart';

/// Topic model used inside DayPlan
class TopicModel {
  String name;
  int estimatedMinutes;
  bool done;

  TopicModel({
    required this.name,
    required this.estimatedMinutes,
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'estimatedMinutes': estimatedMinutes,
    'done': done,
  };

  factory TopicModel.fromJson(Map<String, dynamic> json) => TopicModel(
    name: json['name'] ?? 'Untitled',
    estimatedMinutes: (json['estimatedMinutes'] ?? 0) is int
        ? json['estimatedMinutes']
        : (json['estimatedMinutes'] as num).toInt(),
    done: json['done'] ?? false,
  );
}

/// Day plan containing a date and topics for that day
// class DayPlan {
//   DateTime date;
//   List<TopicModel> topics;
//   int totalMinutes;

//   DayPlan({
//     required this.date,
//     required this.topics,
//     required this.totalMinutes,
//   });

//   Map<String, dynamic> toJson() => {
//     'date': date.toIso8601String(),
//     'totalMinutes': totalMinutes,
//     'topics': topics.map((t) => t.toJson()).toList(),
//   };

//   factory DayPlan.fromJson(dynamic json) {
//     // json might be Map or List (old formats) — handle robustly
//     if (json is Map<String, dynamic>) {
//       final topicsJson = (json['topics'] as List<dynamic>?) ?? <dynamic>[];
//       return DayPlan(
//         date:
//             DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
//         totalMinutes: (json['totalMinutes'] ?? 0) is int
//             ? json['totalMinutes']
//             : (json['totalMinutes'] as num).toInt(),
//         topics: topicsJson
//             .map<TopicModel>((t) {
//               if (t is Map<String, dynamic>) return TopicModel.fromJson(t);
//               return TopicModel.fromJson(Map<String, dynamic>.from(t));
//             })
//             .toList()
//             .cast<TopicModel>(),
//       );
//     } else if (json is List) {
//       // old list-of-topics format -> create DayPlan with today's date
//       final topics = json.map<TopicModel>((t) {
//         if (t is Map<String, dynamic>) return TopicModel.fromJson(t);
//         return TopicModel.fromJson(Map<String, dynamic>.from(t));
//       }).toList();
//       final total = topics.fold<int>(0, (s, t) => s + t.estimatedMinutes);
//       return DayPlan(date: DateTime.now(), topics: topics, totalMinutes: total);
//     } else {
//       // fallback
//       return DayPlan(date: DateTime.now(), topics: [], totalMinutes: 0);
//     }
//   }
// }

/// Plan container (name + days + alarm time)
// class PlanData {
//   String name;
//   List<DayPlan> days;
//   int alarmHour;
//   int alarmMinute;

//   PlanData({
//     required this.name,
//     required this.days,
//     this.alarmHour = 8,
//     this.alarmMinute = 0,
//   });

//   Map<String, dynamic> toJson() => {
//     'name': name,
//     'days': days.map((d) => d.toJson()).toList(),
//     'alarmHour': alarmHour,
//     'alarmMinute': alarmMinute,
//   };

//   factory PlanData.fromJson(Map<String, dynamic> json) {
//     final daysJson = json['days'] as List<dynamic>? ?? <dynamic>[];
//     final days = daysJson.map((d) => DayPlan.fromJson(d)).toList();
//     return PlanData(
//       name: json['name'] ?? 'Untitled Plan',
//       days: days,
//       alarmHour: json['alarmHour'] ?? 8,
//       alarmMinute: json['alarmMinute'] ?? 0,
//     );
//   }
// }

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();

  /// Return current plan stored under 'currentPlan' (or null)
  static Future<PlanData?> getCurrentPlanData() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('currentPlan');
    if (str == null) return null;
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) {
        return PlanData.fromJson(decoded);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Calculate progress across all days/topics (0.0..1.0)
  static double calculateProgress(PlanData plan) {
    int total = 0;
    int done = 0;
    for (final d in plan.days) {
      for (final t in d.topics) {
        total++;
        if (t.done) done++;
      }
    }
    return total == 0 ? 0.0 : done / total;
  }
}

class _PlannerScreenState extends State<PlannerScreen> {
  List<PlanData> savedPlans = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPlans();
  }

  Future<void> _loadSavedPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('savedPlans') ?? [];

    final loaded = <PlanData>[];
    for (final s in list) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map<String, dynamic>) {
          loaded.add(PlanData.fromJson(decoded));
        } else if (decoded is List) {
          // old format: list of DayPlan objects
          final days = decoded.map((d) => DayPlan.fromJson(d)).toList();
          loaded.add(PlanData(name: 'Untitled Plan', days: days));
        }
      } catch (e) {
        debugPrint('Skipping invalid plan data: $e');
      }
    }

    setState(() {
      savedPlans = loaded;
    });
  }

  Future<void> _savePlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = savedPlans.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('savedPlans', jsonList);
  }

  Future<void> _setAsCurrentPlan(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final plan = savedPlans[index];
    await prefs.setString('currentPlan', jsonEncode(plan.toJson()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Set as current plan')));
    setState(() {}); // update UI
  }

  Future<void> _toggleTopicDone(
    int planIndex,
    int dayIndex,
    int topicIndex,
  ) async {
    setState(() {
      final t = savedPlans[planIndex].days[dayIndex].topics[topicIndex];
      t.done = !t.done;
    });
    await _savePlans();

    // if current plan matches this plan (by name + days dates), update currentPlan
    final prefs = await SharedPreferences.getInstance();
    final cur = prefs.getString('currentPlan');
    if (cur != null) {
      try {
        final curDecoded = jsonDecode(cur);
        if (curDecoded is Map<String, dynamic>) {
          // simple compare by serialized values: if names and number of days match, update currentPlan
          final curName = curDecoded['name'];
          if (curName == savedPlans[planIndex].name) {
            await prefs.setString(
              'currentPlan',
              jsonEncode(savedPlans[planIndex].toJson()),
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _editPlanName(int planIndex) async {
    final controller = TextEditingController(text: savedPlans[planIndex].name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Plan Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Plan Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        savedPlans[planIndex].name = result.trim();
      });
      await _savePlans();
    }
  }

  Future<void> _editAlarmTime(int planIndex) async {
    final plan = savedPlans[planIndex];
    final initial = TimeOfDay(hour: plan.alarmHour, minute: plan.alarmMinute);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        plan.alarmHour = picked.hour;
        plan.alarmMinute = picked.minute;
      });
      await _savePlans();
    }
  }

  Future<void> _deletePlan(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: const Text('Are you sure you want to delete this plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => savedPlans.removeAt(index));
      await _savePlans();

      // if deleted plan was current, clear currentPlan
      final prefs = await SharedPreferences.getInstance();
      final cur = prefs.getString('currentPlan');
      if (cur != null) {
        try {
          final curDecoded = jsonDecode(cur);
          if (curDecoded is Map<String, dynamic> &&
              curDecoded['name'] == savedPlans[index].name) {
            await prefs.remove('currentPlan');
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: const Text('All Saved Plans')),
      body: savedPlans.isEmpty
          ? const Center(child: Text('📅 No saved plans yet'))
          : ListView.builder(
              itemCount: savedPlans.length,
              itemBuilder: (context, planIndex) {
                final plan = savedPlans[planIndex];
                final totalMinutes = plan.days.fold<int>(
                  0,
                  (s, d) => s + d.totalMinutes,
                );
                final progress = PlannerScreen.calculateProgress(plan);

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${plan.name} - ${_formatMinutes(totalMinutes)}',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () => _setAsCurrentPlan(planIndex),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editPlanName(planIndex),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deletePlan(planIndex),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: progress, minHeight: 8),
                        const SizedBox(height: 6),
                        Text(
                          'Daily Alarm: ${plan.alarmHour.toString().padLeft(2, '0')}:${plan.alarmMinute.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Edit Alarm Time'),
                        onTap: () => _editAlarmTime(planIndex),
                      ),
                      ...plan.days.asMap().entries.map((dayEntry) {
                        final dayIndex = dayEntry.key;
                        final day = dayEntry.value;
                        return ExpansionTile(
                          title: Text(
                            'Day ${dayIndex + 1} - ${dateFormat.format(day.date)} (${_formatMinutes(day.totalMinutes)})',
                          ),
                          children: day.topics.asMap().entries.map((tEntry) {
                            final topicIndex = tEntry.key;
                            final topic = tEntry.value;
                            return CheckboxListTile(
                              value: topic.done,
                              title: Text(topic.name),
                              subtitle: Text('${topic.estimatedMinutes} min'),
                              onChanged: (_) => _toggleTopicDone(
                                planIndex,
                                dayIndex,
                                topicIndex,
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
