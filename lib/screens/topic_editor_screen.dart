import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class TopicEditorScreen extends StatefulWidget {
  final Map<String, dynamic> parsedJson;

  const TopicEditorScreen({super.key, required this.parsedJson});

  @override
  State<TopicEditorScreen> createState() => _TopicEditorScreenState();
}

class _TopicEditorScreenState extends State<TopicEditorScreen> {
  late List<Map<String, dynamic>> units;
  final uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    units = _parseJson(widget.parsedJson);
  }

  List<Map<String, dynamic>> _parseJson(Map<String, dynamic> json) {
    if (json.containsKey("units") && json["units"] is List) {
      return List<Map<String, dynamic>>.from(json["units"]);
    }
    return [];
  }

  void _addTopic(Map<String, dynamic> unit) {
    setState(() {
      unit["topics"] ??= [];
      unit["topics"].add({
        "id": uuid.v4(),
        "name": "New Topic",
        "estimated_time": 30,
        "importance": 3,
        "difficulty": 2,
        "resources": [],
        "subtopics": [],
      });
    });
  }

  void _addSubtopic(Map<String, dynamic> topic) {
    setState(() {
      topic["subtopics"] ??= [];
      topic["subtopics"].add({
        "id": uuid.v4(),
        "name": "New Subtopic",
        "estimated_time": 15,
        "importance": 2,
        "difficulty": 1,
        "resources": [],
      });
    });
  }

  void _editItem(Map<String, dynamic> item) async {
    final controller = TextEditingController(text: item["name"]);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      setState(() {
        item["name"] = newName.trim();
      });
    }
  }

  void _deleteItem(List list, Map<String, dynamic> item) {
    setState(() {
      list.remove(item);
    });
  }

  Widget _buildSubtopics(List subtopics) {
    return Column(
      children: subtopics.map((sub) {
        return ListTile(
          title: Text(sub["name"] ?? "Untitled Subtopic"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editItem(sub),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteItem(subtopics, sub),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopics(List topics) {
    return Column(
      children: topics.map((topic) {
        return ExpansionTile(
          title: Text(topic["name"] ?? "Untitled Topic"),
          children: [
            _buildSubtopics(topic["subtopics"] ?? []),
            TextButton.icon(
              onPressed: () => _addSubtopic(topic),
              icon: const Icon(Icons.add),
              label: const Text("Add Subtopic"),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editItem(topic),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteItem(topics, topic),
                ),
              ],
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Topic Editor")),
      body: ListView(
        children: units.map((unit) {
          return Card(
            child: ExpansionTile(
              title: Text(unit["name"] ?? "Untitled Unit"),
              children: [
                _buildTopics(unit["topics"] ?? []),
                TextButton.icon(
                  onPressed: () => _addTopic(unit),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Topic"),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editItem(unit),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteItem(units, unit),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
