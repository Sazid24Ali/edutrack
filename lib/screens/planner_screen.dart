import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plan_preview_screen.dart';
import 'package:intl/intl.dart';
import "planning_screen.dart";

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

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

class _PlannerScreenState extends State<PlannerScreen> {
  List<PlanData> savedPlans = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPlans();
  }

  Future<void> _loadSavedPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPlansJson = prefs.getStringList('savedPlans') ?? [];
    // print(savedPlansJson);
    final loadedPlans = savedPlansJson.map((planStr) {
      final jsonMap = Map<String, dynamic>.from(jsonDecode(planStr));
      return PlanData.fromJson(jsonMap);
    }).toList();

    setState(() {
      savedPlans = loadedPlans;
      print(savedPlans);
    });
  }

  Future<void> _savePlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = savedPlans.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('savedPlans', jsonList);
  }

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Future<void> _editPlanName(PlanData plan) async {
    final controller = TextEditingController(text: plan.name);
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

    if (result != null && result.isNotEmpty) {
      setState(() {
        plan.name = result;
      });
      _savePlans();
    }
  }

  Future<void> _editAlarmTime(PlanData plan) async {
    TimeOfDay alarmTime = TimeOfDay(
      hour: plan.alarmHour,
      minute: plan.alarmMinute,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: alarmTime,
    );
    if (picked != null) {
      setState(() {
        plan.alarmHour = picked.hour;
        plan.alarmMinute = picked.minute;
      });
      _savePlans();
    }
  }

  Future<void> _deletePlan(int index) async {
    final confirm = await showDialog<bool>(
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        savedPlans.removeAt(index);
      });
      _savePlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    if (savedPlans.isEmpty) {
      return const Scaffold(body: Center(child: Text("📅 No saved plans yet")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('All Saved Plans')),
      body: ListView.builder(
        itemCount: savedPlans.length,
        itemBuilder: (context, planIndex) {
          final plan = savedPlans[planIndex];
          int totalMinutes = plan.days.fold(
            0,
            (sum, day) => sum + day.totalMinutes,
          );

          return Card(
            margin: const EdgeInsets.all(8),
            child: ExpansionTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${plan.name} - Total: ${formatMinutes(totalMinutes)}',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editPlanName(plan),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePlan(planIndex),
                  ),
                ],
              ),
              subtitle: Text(
                'Daily Alarm: ${plan.alarmHour.toString().padLeft(2, '0')}:${plan.alarmMinute.toString().padLeft(2, '0')}',
              ),
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Edit Alarm Time'),
                  onTap: () => _editAlarmTime(plan),
                ),
                ...plan.days.map((day) {
                  return ExpansionTile(
                    title: Text(
                      'Day ${plan.days.indexOf(day) + 1} - ${dateFormat.format(day.date)} (${formatMinutes(day.totalMinutes)})',
                    ),
                    children: day.topics.map((t) {
                      return ListTile(
                        title: Text(t.name),
                        subtitle: Text(formatMinutes(t.estimatedMinutes)),
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
}
