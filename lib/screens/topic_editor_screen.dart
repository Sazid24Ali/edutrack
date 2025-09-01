import 'package:flutter/material.dart';
import "planning_screen.dart";

/// TopicEditorScreen - full drop-in file
/// - Normalizes different JSON shapes (units / weekly_schedule / topics)
/// - Inline card UI with icons (edit / delete / add)
/// - Live updates of total times shown by clock icons
/// - Returns edited syllabus Map on Save (Navigator.pop(context, _syllabus))
class TopicEditorScreen extends StatefulWidget {
  final Map<String, dynamic> parsedJson;
  const TopicEditorScreen({super.key, required this.parsedJson});

  @override
  State<TopicEditorScreen> createState() => _TopicEditorScreenState();
}

class _TopicEditorScreenState extends State<TopicEditorScreen> {
  late Map<String, dynamic> _syllabus;
  late String _rootKey;
  late List<dynamic> _rootList;
  bool _isEdited = false;

  @override
  void initState() {
    super.initState();
    // Shallow copy top-level map so we can mutate nested lists (they remain same refs)
    _syllabus = Map<String, dynamic>.from(widget.parsedJson);

    // Determine root list: prefer 'units', then 'weekly_schedule', then 'topics'
    if (_syllabus.containsKey('units') && _syllabus['units'] is List) {
      _rootKey = 'units';
    } else if (_syllabus.containsKey('weekly_schedule') &&
        _syllabus['weekly_schedule'] is List) {
      _rootKey = 'weekly_schedule';
    } else if (_syllabus.containsKey('topics') && _syllabus['topics'] is List) {
      _rootKey = 'topics';
    } else {
      // create a root list if none exists
      _rootKey = 'units';
      _syllabus[_rootKey] = <dynamic>[];
    }

    _rootList = _syllabus[_rootKey] as List<dynamic>;

    // Normalize the existing nodes so UI and calculations are consistent
    for (final node in _rootList) {
      if (node is Map<String, dynamic>) {
        _normalizeUnitShape(node);
      }
    }
    // initial recalc
    setState(() {});
  }

  void _markEdited() {
    if (!_isEdited) {
      setState(() => _isEdited = true);
    }
  }

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  int _clamp(int v, int min, int max) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  // ---------------- Normalization ----------------

  // Ensure unit has 'unit_title' and 'topics' list
  void _normalizeUnitShape(Map<String, dynamic> unit) {
    unit['unit_title'] =
        unit['unit_title'] ??
        unit['unit_name'] ??
        unit['title'] ??
        unit['topic'] ??
        unit['name'] ??
        unit['unit'] ??
        'Unit';

    // Some inputs put topics under 'topics' or 'subtopics'
    if (unit['topics'] is List) {
      for (final t in (unit['topics'] as List)) {
        if (t is Map<String, dynamic>) _normalizeTopicShape(t);
      }
    } else if (unit['subtopics'] is List && unit['topics'] == null) {
      unit['topics'] = unit['subtopics'];
      for (final t in (unit['topics'] as List)) {
        if (t is Map<String, dynamic>) _normalizeTopicShape(t);
      }
    } else if (unit.containsKey('topic') && unit['topics'] == null) {
      // wrap single topic form into topics list
      final wrapped = <String, dynamic>{
        'title': unit['topic'] ?? unit['title'] ?? 'Untitled',
        'estimated_time': _toInt(unit['estimated_time'], fallback: 0),
        'importance': _clamp(_toInt(unit['importance'], fallback: 3), 1, 5),
        'difficulty': _clamp(_toInt(unit['difficulty'], fallback: 2), 1, 5),
        'subtopics': unit['subtopics'] ?? <dynamic>[],
      };
      unit['topics'] = [wrapped];
      for (final t in (unit['topics'] as List)) {
        if (t is Map<String, dynamic>) _normalizeTopicShape(t);
      }
    } else {
      unit['topics'] ??= <dynamic>[];
    }
  }

  // Ensure topic has keys: title, estimated_time(int), importance, difficulty, subtopics(list)
  void _normalizeTopicShape(Map<String, dynamic> t) {
    t['title'] = t['title'] ?? t['topic'] ?? t['name'] ?? 'Untitled';
    t['estimated_time'] = _toInt(t['estimated_time'], fallback: 0);
    t['importance'] = _clamp(_toInt(t['importance'], fallback: 3), 1, 5);
    t['difficulty'] = _clamp(_toInt(t['difficulty'], fallback: 2), 1, 5);
    if (t['subtopics'] is! List) t['subtopics'] ??= <dynamic>[];
    // recurse
    for (final s in (t['subtopics'] as List<dynamic>)) {
      if (s is Map<String, dynamic>) _normalizeTopicShape(s);
    }
  }

  // ---------------- Time calculations ----------------

  // returns sum of this topic's own estimated_time + all nested subtopics
  int _calculateTotalTimeForTopic(Map<String, dynamic> topic) {
    int total = _toInt(topic['estimated_time'], fallback: 0);
    final subs = (topic['subtopics'] as List<dynamic>?) ?? [];
    for (final s in subs) {
      if (s is Map<String, dynamic>) total += _calculateTotalTimeForTopic(s);
    }
    return total;
  }

  // returns unit total by summing topic totals
  int _calculateTotalTimeForUnit(Map<String, dynamic> unit) {
    int total = 0;
    final topics = (unit['topics'] as List<dynamic>?) ?? <dynamic>[];
    for (final t in topics) {
      if (t is Map<String, dynamic>) total += _calculateTotalTimeForTopic(t);
    }
    return total;
  }

  // ---------------- CRUD ops ----------------

  Future<void> _editTopicDialog(Map<String, dynamic> topic) async {
    _normalizeTopicShape(topic);
    final titleCtrl = TextEditingController(
      text: topic['title']?.toString() ?? '',
    );
    final timeCtrl = TextEditingController(
      text: topic['estimated_time']?.toString() ?? '0',
    );
    final impCtrl = TextEditingController(
      text: topic['importance']?.toString() ?? '3',
    );
    final diffCtrl = TextEditingController(
      text: topic['difficulty']?.toString() ?? '2',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Topic'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: timeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estimated time (mins)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: impCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Importance (1-5)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: diffCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty (1-5)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      setState(() {
        topic['title'] = titleCtrl.text.trim().isEmpty
            ? 'Untitled'
            : titleCtrl.text.trim();
        topic['estimated_time'] = _toInt(
          timeCtrl.text,
          fallback: topic['estimated_time'] ?? 0,
        );
        topic['importance'] = _clamp(
          _toInt(impCtrl.text, fallback: topic['importance'] ?? 3),
          1,
          5,
        );
        topic['difficulty'] = _clamp(
          _toInt(diffCtrl.text, fallback: topic['difficulty'] ?? 2),
          1,
          5,
        );
        // ensure normalized and persist
        _normalizeTopicShape(topic);
        _syllabus[_rootKey] = _rootList;
        _markEdited();
      });
    }
  }

  Future<void> _addTopicDialog(Map<String, dynamic> unit) async {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Topic'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Topic title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: timeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated time (mins)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (added == true) {
      setState(() {
        unit['topics'] ??= <dynamic>[];
        final newTopic = <String, dynamic>{
          'title': titleCtrl.text.trim().isEmpty
              ? 'New Topic'
              : titleCtrl.text.trim(),
          'estimated_time': _toInt(timeCtrl.text, fallback: 0),
          'importance': 3,
          'difficulty': 2,
          'subtopics': <dynamic>[],
        };
        unit['topics'].add(newTopic);
        _syllabus[_rootKey] = _rootList;
        _markEdited();
      });
    }
  }

  Future<void> _addSubtopicDialog(Map<String, dynamic> parentTopic) async {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Subtopic'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Subtopic title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: timeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated time (mins)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (added == true) {
      setState(() {
        parentTopic['subtopics'] ??= <dynamic>[];
        final newSub = <String, dynamic>{
          'title': titleCtrl.text.trim().isEmpty
              ? 'New Subtopic'
              : titleCtrl.text.trim(),
          'estimated_time': _toInt(timeCtrl.text, fallback: 0),
          'importance': 3,
          'difficulty': 2,
          'subtopics': <dynamic>[],
        };
        (parentTopic['subtopics'] as List).add(newSub);
        _syllabus[_rootKey] = _rootList;
        _markEdited();
      });
    }
  }

  Future<void> _confirmDelete(List<dynamic> parentList, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete'),
          content: const Text('Are you sure you want to delete this item?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        parentList.removeAt(index);
        _syllabus[_rootKey] = _rootList;
        _markEdited();
      });
    }
  }

  // ---------------- UI building ----------------

  // Topic card (recursive). parentList is the list that contains this topic (so delete works).
  Widget _buildTopicCard(
    Map<String, dynamic> topic,
    List<dynamic> parentList,
    int index, {
    bool isSub = false,
  }) {
    _normalizeTopicShape(topic);
    final totalTopicTime = _calculateTotalTimeForTopic(topic);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: isSub ? 28 : 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: ValueKey(topic.hashCode ^ index),
        title: Row(
          children: [
            Expanded(
              child: Text(
                topic['title']?.toString() ?? 'Untitled',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.alarm, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Text(
                  '$totalTopicTime min',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Text('${topic['importance'] ?? 3}'),
              const SizedBox(width: 12),
              const Icon(Icons.bolt, size: 14, color: Colors.purple),
              const SizedBox(width: 4),
              Text('${topic['difficulty'] ?? 2}'),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 12, right: 8, bottom: 12),
        children: [
          // Button bar with edit, add, delete, plan
          ButtonBar(
            alignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.green),
                tooltip: 'Edit',
                onPressed: () => _editTopicDialog(topic),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: 'Add subtopic',
                onPressed: () => _addSubtopicDialog(topic),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(parentList, index),
              ),
              const SizedBox(height: 10),
            ],
          ),

          // Nested subtopics
          if ((topic['subtopics'] as List<dynamic>?)?.isNotEmpty ?? false)
            ...List.generate((topic['subtopics'] as List).length, (i) {
              final child = topic['subtopics'][i];
              if (child is Map<String, dynamic>) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: _buildTopicCard(
                    child,
                    topic['subtopics'],
                    i,
                    isSub: true,
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            }),
        ],
      ),
    );
  }

  Widget _buildUnitCard(Map<String, dynamic> unit, int unitIndex) {
    _normalizeUnitShape(unit);
    final unitTotal = _calculateTotalTimeForUnit(unit);
    final topics = (unit['topics'] as List<dynamic>?) ?? <dynamic>[];

    return Card(
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        key: ValueKey(unit.hashCode ^ unitIndex),
        leading: const Icon(Icons.menu_book),
        title: Row(
          children: [
            Expanded(
              child: Text(
                unit['unit_title']?.toString() ?? 'Unit ${unitIndex + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.alarm, size: 18),
            const SizedBox(width: 6),
            Text(
              '$unitTotal min',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        children: [
          if (topics.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No topics. Add one below.'),
            ),
          ...List.generate(topics.length, (tIndex) {
            final t = topics[tIndex];
            if (t is Map<String, dynamic>) {
              return _buildTopicCard(t, topics, tIndex);
            }
            return const SizedBox.shrink();
          }),
          ButtonBar(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Topic'),
                onPressed: () => _addTopicDialog(unit),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Delete Unit'),
                onPressed: () => _confirmDelete(_rootList, unitIndex),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- Save / Pop handling ----------------

  Future<bool> _onWillPop() async {
    if (!_isEdited) return true;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('Do you want to save changes before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 1),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 1) {
      Navigator.pop(context, _syllabus);
      return false;
    } else if (result == 2) {
      Navigator.pop(context);
      return false;
    } else {
      return false;
    }
  }

  // ---------- Build UI ----------

  @override
  Widget build(BuildContext context) {
    // calculate total syllabus time
    int totalSyllabusTime = 0;
    for (final unitRaw in _rootList) {
      if (unitRaw is Map<String, dynamic>) {
        totalSyllabusTime += _calculateTotalTimeForUnit(unitRaw);
      }
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_syllabus['course_title']?.toString() ?? 'Topic Editor'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save and return',
              onPressed: () => Navigator.pop(context, _syllabus),
            ),
            IconButton(
              icon: const Icon(Icons.calendar_month),
              tooltip: 'Plan Syllabus',
              onPressed: _planSyllabus,
            ),
          ],
        ),
        body: Stack(
          children: [
            _rootList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No units found.'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _showAddUnitDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Unit'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _rootList.length,
                    itemBuilder: (context, idx) {
                      final unitRaw = _rootList[idx];
                      if (unitRaw is! Map<String, dynamic>)
                        return const SizedBox.shrink();
                      return _buildUnitCard(unitRaw, idx);
                    },
                  ),
            // Footer "Plan Syllabus" button with total time
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white.withOpacity(0.9),
                child: ElevatedButton.icon(
                  onPressed: _planSyllabus,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Plan Syllabus ($totalSyllabusTime min)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddUnitDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _planSyllabus() {
    // Flatten all topics from all units
    List<Topic> allTopics = [];

    void extractTopics(Map<String, dynamic> node) {
      if (node.containsKey('title') && node.containsKey('estimated_time')) {
        allTopics.add(
          Topic(
            name: node['title'],
            estimatedMinutes: node['estimated_time'] ?? 30,
            isIncluded: true,
          ),
        );
      }
      if (node.containsKey('subtopics')) {
        for (var child in node['subtopics']) {
          if (child is Map<String, dynamic>) extractTopics(child);
        }
      }
    }

    for (final unitRaw in _rootList) {
      if (unitRaw is Map<String, dynamic>) {
        final topics = (unitRaw['topics'] as List<dynamic>?) ?? [];
        for (final t in topics) {
          if (t is Map<String, dynamic>) extractTopics(t);
        }
      }
    }

    // Navigate to PlanningScreen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlanningScreen(topics: allTopics)),
    );
  }

  // Add unit dialog
  Future<void> _showAddUnitDialog() async {
    final titleCtrl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Unit'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Unit title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added == true) {
      setState(() {
        final newUnit = <String, dynamic>{
          'unit_title': titleCtrl.text.trim().isEmpty
              ? 'New Unit'
              : titleCtrl.text.trim(),
          'topics': <dynamic>[],
        };
        _rootList.add(newUnit);
        _syllabus[_rootKey] = _rootList;
        _markEdited();
      });
    }
  }
}
