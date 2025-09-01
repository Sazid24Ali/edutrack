import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  List<AlarmSettings> _alarms = [];
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAlarmPlugin();
  }

  Future<void> _initAlarmPlugin() async {
    await _checkAndRequestPermissions();
    await Alarm.init();
    _loadAlarms();
  }

  Future<void> _checkAndRequestPermissions() async {
    var status = await Permission.scheduleExactAlarm.status;
    if (!status.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> _loadAlarms() async {
    final alarms = await Alarm.getAlarms();
    setState(() {
      _alarms = alarms;
      _alarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    });
  }

  Future<void> _showSetAlarmDialog({AlarmSettings? alarmToEdit}) async {
    DateTime initialDate = alarmToEdit?.dateTime ?? DateTime.now();
    TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
    _titleController.text = alarmToEdit?.notificationSettings.title ?? '';

    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate == null) return;

    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (selectedTime == null) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          alarmToEdit == null ? 'Set Alarm Title' : 'Edit Alarm Title',
        ),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: 'Enter title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty) {
                final selectedDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                _setOrUpdateAlarm(
                  selectedDateTime,
                  _titleController.text,
                  alarmToEdit,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _setOrUpdateAlarm(
    DateTime dateTime,
    String title,
    AlarmSettings? existingAlarm,
  ) async {
    final alarmSettings = AlarmSettings(
      id: existingAlarm?.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
      dateTime: dateTime,
      assetAudioPath: 'assets/sounds/alarm.mp3', // Make sure file exists
      loopAudio: true,
      vibrate: true,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 3),
      ),
      notificationSettings: NotificationSettings(
        title: title,
        body: 'Your alarm is ringing!',
        stopButton: 'Stop',
        icon: 'notification_icon',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
    _loadAlarms();
  }

  Future<void> _confirmDelete(int id) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alarm'),
        content: const Text('Are you sure you want to delete this alarm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Alarm.stop(id);
      _loadAlarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Alarms')),
      body: _alarms.isEmpty
          ? const Center(
              child: Text(
                'No active alarms.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _alarms.length,
              itemBuilder: (context, index) {
                final alarm = _alarms[index];
                final formattedTime = DateFormat(
                  'E, dd MMM yyyy, hh:mm a',
                ).format(alarm.dateTime);
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 16.0,
                    ),
                    leading: const Icon(
                      Icons.alarm,
                      size: 40,
                      color: Colors.indigo,
                    ),
                    title: Text(
                      alarm.notificationSettings.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(formattedTime),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () =>
                              _showSetAlarmDialog(alarmToEdit: alarm),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(alarm.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSetAlarmDialog(),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Set Custom Alarm'),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}
