import 'package:flutter/material.dart';

class SyllabusScreen extends StatefulWidget {
  final Map<String, dynamic> syllabusData; // parsed JSON from Gemini

  const SyllabusScreen({super.key, required this.syllabusData});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  late List<dynamic> _units;

  @override
  void initState() {
    super.initState();
    _units = widget.syllabusData["weekly_schedule"] ?? [];
  }

  void _editTopic(int unitIndex, int topicIndex) async {
    final topic = _units[unitIndex]["subtopics"][topicIndex];
    final TextEditingController timeCtrl = TextEditingController(
      text: topic["estimated_time"].toString(),
    );
    final TextEditingController importanceCtrl = TextEditingController(
      text: topic["importance"].toString(),
    );
    final TextEditingController difficultyCtrl = TextEditingController(
      text: topic["difficulty"].toString(),
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Topic: ${topic["topic"]}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: timeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Estimated Time (mins)",
              ),
            ),
            TextField(
              controller: importanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Importance (1-5)"),
            ),
            TextField(
              controller: difficultyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Difficulty (1-5)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                topic["estimated_time"] = int.tryParse(timeCtrl.text) ?? 0;
                topic["importance"] = int.tryParse(importanceCtrl.text) ?? 3;
                topic["difficulty"] = int.tryParse(difficultyCtrl.text) ?? 3;
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteTopic(int unitIndex, int topicIndex) {
    setState(() {
      _units[unitIndex]["subtopics"].removeAt(topicIndex);
    });
  }

  void _addTopic(int unitIndex) async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController timeCtrl = TextEditingController();
    final TextEditingController importanceCtrl = TextEditingController();
    final TextEditingController difficultyCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Topic"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Topic Name"),
            ),
            TextField(
              controller: timeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Estimated Time (mins)",
              ),
            ),
            TextField(
              controller: importanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Importance (1-5)"),
            ),
            TextField(
              controller: difficultyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Difficulty (1-5)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _units[unitIndex]["subtopics"].add({
                  "topic": nameCtrl.text,
                  "estimated_time": int.tryParse(timeCtrl.text) ?? 0,
                  "importance": int.tryParse(importanceCtrl.text) ?? 3,
                  "difficulty": int.tryParse(difficultyCtrl.text) ?? 3,
                });
              });
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parsed Syllabus")),
      body: ListView.builder(
        itemCount: _units.length,
        itemBuilder: (context, unitIndex) {
          final unit = _units[unitIndex];
          final List<dynamic> topics = unit["subtopics"] ?? [];

          return ExpansionTile(
            title: Text("Week ${unit["week_number"]}: ${unit["topic"]}"),
            subtitle: Text("Topics: ${topics.length}"),
            children: [
              ...topics.asMap().entries.map((entry) {
                final topicIndex = entry.key;
                final topic = entry.value;
                return ListTile(
                  title: Text(topic["topic"] ?? "Untitled"),
                  subtitle: Text(
                    "Time: ${topic["estimated_time"]}m | Importance: ${topic["importance"]} | Difficulty: ${topic["difficulty"]}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _editTopic(unitIndex, topicIndex),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        onPressed: () => _deleteTopic(unitIndex, topicIndex),
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () => _addTopic(unitIndex),
                icon: const Icon(Icons.add),
                label: const Text("Add Topic"),
              ),
            ],
          );
        },
      ),
    );
  }
}
