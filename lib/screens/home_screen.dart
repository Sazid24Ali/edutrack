import 'package:edutrack/screens/alarm_screen.dart';
import 'package:flutter/material.dart';
import 'planner_screen.dart';
import 'study_files_screen.dart';
import 'focus_mode_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EduTrack Home')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlannerScreen()),
                );
              },
              icon: const Icon(Icons.schedule),
              label: const Text('Current Plan'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FocusModeScreen()),
                );
              },
              icon: const Icon(Icons.do_not_disturb),
              label: const Text('Focus Mode'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlarmScreen()),
                );
              },
              icon: const Icon(Icons.alarm),
              label: const Text('Alarm'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyFilesScreen()),
                );
              },
              icon: const Icon(Icons.folder),
              label: const Text('Study Files'),
            ),
          ],
        ),
      ),
    );
  }
}


