import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'study_files_screen.dart'; // your existing PDF folder screen

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  Duration _focusDuration = const Duration(minutes: 5);
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startFocusTimer() async {
    setState(() {
      _timeLeft = _focusDuration;
      _isRunning = true;
    });

    final alarmId = DateTime.now().millisecondsSinceEpoch % 100000;
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarmId,
        dateTime: DateTime.now().add(_focusDuration),
        assetAudioPath: 'assets/sounds/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: const Duration(seconds: 3),
        ),
        notificationSettings: NotificationSettings(
          title: 'Focus Timer Finished',
          body: 'Time to take a break!',
          stopButton: 'Stop',
          icon: 'notification_icon',
        ),
      ),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft.inSeconds <= 0) {
        timer.cancel();
        setState(() => _isRunning = false);
      } else {
        setState(() => _timeLeft -= const Duration(seconds: 1));
      }
    });
  }

  void _stopFocusTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  Future<void> _setFocusDuration() async {
    final TimeOfDay? result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _focusDuration.inHours,
        minute: _focusDuration.inMinutes % 60,
      ),
    );
    if (result != null) {
      setState(() {
        _focusDuration = Duration(hours: result.hour, minutes: result.minute);
      });
    }
  }

  String _formattedTimeLeft() {
    final minutes = _timeLeft.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _timeLeft.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '${_timeLeft.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Focus Mode'),
        backgroundColor: const Color.fromARGB(255, 182, 212, 194),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.center, // center vertically
          // crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              _formattedTimeLeft(),
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 20),
            if (!_isRunning)
              ElevatedButton.icon(
                onPressed: _setFocusDuration,
                icon: const Icon(Icons.timer, size: 24),
                label: Text(
                  'Set Focus Duration (${_focusDuration.inMinutes} min)',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 55,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRunning ? _stopFocusTimer : _startFocusTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunning ? Colors.redAccent : Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: Colors.black54,
              ),
              child: Text(
                _isRunning ? 'Stop Focus' : 'Start Focus',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (_isRunning)
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: StudyFilesScreenOnlyPDF(), // restricted PDF folder
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget for restricted PDF folder
class StudyFilesScreenOnlyPDF extends StatelessWidget {
  const StudyFilesScreenOnlyPDF({super.key});

  @override
  Widget build(BuildContext context) {
    return StudyFilesScreen();
  }
}
