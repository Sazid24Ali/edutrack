// lib/screens/home_screen.dart
import 'package:edutrack/models/plan_data.dart';
import 'package:edutrack/screens/planner_screen.dart';
import 'package:flutter/material.dart';
import 'study_files_screen.dart';
import 'focus_mode_screen.dart';
import 'alarm_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PlanData? _currentPlan;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCurrentPlan();
  }

  Future<void> _loadCurrentPlan() async {
    final plan = await PlannerScreen.getCurrentPlanData();
    if (plan != null) {
      setState(() {
        _currentPlan = plan as PlanData?;
        _progress = PlannerScreen.calculateProgress(plan);
      });
    } else {
      setState(() {
        _currentPlan = null;
        _progress = 0.0;
      });
    }
  }

  Future<void> _openPlannerAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlannerScreen()),
    );
    await _loadCurrentPlan();
  }

  Widget _buildGridButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.9), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCircle() {
    final displayPercent = (_progress * 100).clamp(0.0, 100.0);
    return GestureDetector(
      onTap: _openPlannerAndRefresh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // background circle
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 12,
                  color: Colors.grey.shade300,
                ),
                // progress circle on top
                CircularProgressIndicator(
                  value: _progress.clamp(0.0, 1.0),
                  strokeWidth: 12,
                  color: Colors.green,
                ),
                // center text
                Center(
                  child: Text(
                    '${displayPercent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _currentPlan?.name ?? 'No active plan',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // grid features
    final features = [
      {
        'icon': Icons.schedule,
        'label': 'Planner',
        'color': Colors.blue,
        'action': _openPlannerAndRefresh,
      },
      {
        'icon': Icons.do_not_disturb,
        'label': 'Focus Mode',
        'color': Colors.deepPurple,
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FocusModeScreen()),
          );
        },
      },
      {
        'icon': Icons.alarm,
        'label': 'Alarm',
        'color': Colors.red,
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AlarmScreen()),
          );
        },
      },
      {
        'icon': Icons.folder,
        'label': 'Study Files',
        'color': Colors.green,
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudyFilesScreen()),
          );
        },
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('EduTrack Home')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_currentPlan != null) ...[
              _buildProgressCircle(),
              const SizedBox(height: 20),
            ],
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: features.map((f) {
                  return _buildGridButton(
                    icon: f['icon'] as IconData,
                    label: f['label'] as String,
                    color: f['color'] as Color,
                    onTap: f['action'] as VoidCallback,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
