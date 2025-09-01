import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'plan_preview_screen.dart';

class Topic {
  String name;
  int estimatedMinutes;
  bool isIncluded;

  Topic({
    required this.name,
    required this.estimatedMinutes,
    this.isIncluded = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'estimatedMinutes': estimatedMinutes,
    'isIncluded': isIncluded,
  };

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
    name: json['name'],
    estimatedMinutes: json['estimatedMinutes'],
    isIncluded: json['isIncluded'] ?? true,
  );
}

class PlanningScreen extends StatefulWidget {
  final List<Topic> topics;

  const PlanningScreen({super.key, required this.topics});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  double _hoursPerDay = 2; // user input hours per day
  int? _dailyLimitMinutes;

  int get _totalMinutes {
    return widget.topics
        .where((t) => t.isIncluded)
        .fold(0, (sum, t) => sum + t.estimatedMinutes);
  }

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().add(const Duration(days: 1));
    _calculateEndDate();
  }

  void _calculateEndDate() {
    if (_hoursPerDay <= 0) return;
    final daysNeeded = (_totalMinutes / (_hoursPerDay * 60)).ceil();
    _endDate = _startDate!.add(Duration(days: daysNeeded - 1));
    _dailyLimitMinutes = (_hoursPerDay * 60).ceil();
  }

  void _calculateHoursPerDay() {
    if (_startDate == null || _endDate == null) return;
    final days = _endDate!.difference(_startDate!).inDays + 1;
    _hoursPerDay = _totalMinutes / 60 / days;
    _dailyLimitMinutes = (_hoursPerDay * 60).ceil();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate!,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _calculateEndDate();
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate!,
      firstDate: _startDate!.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _calculateHoursPerDay();
      });
    }
  }

  void _generatePlan() {
    final includedTopics = widget.topics.where((t) => t.isIncluded).toList();
    if (includedTopics.isEmpty || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select dates and include topics.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanPreviewScreen(
          topics: includedTopics,
          startDate: _startDate!,
          numDays: _endDate!.difference(_startDate!).inDays + 1,
          dailyLimitMinutes: _dailyLimitMinutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: const Text('Plan Your Syllabus')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(
                _startDate != null ? dateFormat.format(_startDate!) : '',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickStartDate,
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(
                _endDate != null ? dateFormat.format(_endDate!) : '',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickEndDate,
            ),
            ListTile(
              title: const Text('Hours Per Day'),
              trailing: SizedBox(
                width: 60,
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: _hoursPerDay.toStringAsFixed(1),
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null && parsed > 0) {
                      setState(() {
                        _hoursPerDay = parsed;
                        _calculateEndDate();
                      });
                    }
                  },
                ),
              ),
            ),
            if (_dailyLimitMinutes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Daily Study Limit: $_dailyLimitMinutes min',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Topics to Include',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.topics.length,
                itemBuilder: (context, index) {
                  final t = widget.topics[index];
                  return CheckboxListTile(
                    value: t.isIncluded,
                    title: Text('${t.name} (${t.estimatedMinutes} min)'),
                    onChanged: (v) {
                      setState(() {
                        t.isIncluded = v ?? true;
                        _calculateEndDate();
                      });
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _generatePlan,
              child: const Text('Generate Plan'),
            ),
          ],
        ),
      ),
    );
  }
}
