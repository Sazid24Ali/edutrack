import 'package:flutter/material.dart';
import 'study_files_screen.dart';

class FocusModeScreen extends StatelessWidget {
  const FocusModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Focus Mode')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StudyFilesScreen(),
              ),
            );
          },
          icon: const Icon(Icons.folder),
          label: const Text('Open Study Files'),
        ),
      ),
    );
  }
}
