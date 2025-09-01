import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/gemini_service.dart';
import 'topic_editor_screen.dart';

/// OcrScreen
/// - Pick image (camera/gallery)
/// - Run ML Kit OCR
/// - Send OCR text to GeminiService.parseSyllabus(...)
/// - Save recent scans in SharedPreferences
/// - Open TopicEditorScreen and persist edits
class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isLoading = false;
  String _statusMessage = 'Pick an image to extract text and analyze.';
  String _extractedText = '';

  // recent scans stored in memory as List<Map>
  List<Map<String, dynamic>> _recentParsedDataRaw = [];

  static const String _prefsKey = 'recent_scans';

  @override
  void initState() {
    super.initState();
    _loadRecentScans();
  }

  Future<void> _loadRecentScans() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading recent scans...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = json.decode(raw) as List<dynamic>;
        _recentParsedDataRaw = decoded.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        }).toList();
        setState(() {
          _statusMessage = 'Loaded ${_recentParsedDataRaw.length} scans';
        });
      } else {
        setState(() {
          _recentParsedDataRaw = [];
          _statusMessage = 'No recent scans';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading scans: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final encoded = json.encode(_recentParsedDataRaw);
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('Error saving scans: $e');
    }
  }

  // Image picking entry
  Future<void> _pickImage(ImageSource src) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: src,
        imageQuality: 80,
      );
      if (picked == null) return;
      final file = File(picked.path);
      setState(() {
        _selectedImage = file;
      });
      await _processImage(file);
    } catch (e) {
      setState(() {
        _statusMessage = 'Image pick error: $e';
      });
    }
  }

  // Process image: OCR -> Gemini -> save scan -> open editor
  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Running OCR...';
    });

    final textRecognizer = TextRecognizer();

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognized = await textRecognizer.processImage(
        inputImage,
      );
      _extractedText = recognized.text.trim();
      if (_extractedText.isEmpty) {
        setState(() {
          _statusMessage = 'No text found in image.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Sending to Gemini for parsing...';
      });

      final Map<String, dynamic>? parsedJson =
          await GeminiService.parseSyllabus(_extractedText);

      if (parsedJson == null) {
        setState(() {
          _statusMessage = 'Gemini returned null or failed.';
          _isLoading = false;
        });
        return;
      }

      if (parsedJson.containsKey('error')) {
        setState(() {
          _statusMessage = parsedJson['error'].toString();
          _isLoading = false;
        });
        return;
      }

      final scan = <String, dynamic>{
        'title':
            parsedJson['course_title'] ??
            'Scan ${DateTime.now().toLocal().toString().substring(0, 16)}',
        'parsedJson': parsedJson,
        'timestamp': DateTime.now().toIso8601String(),
        'imagePath': imageFile.path,
      };

      setState(() {
        _recentParsedDataRaw.insert(0, scan);
        if (_recentParsedDataRaw.length > 20) {
          _recentParsedDataRaw = _recentParsedDataRaw.sublist(0, 20);
        }
      });
      await _saveRecentScans();

      final int insertedIndex = 0;
      final updated = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (_) => TopicEditorScreen(parsedJson: parsedJson),
        ),
      );

      if (updated != null) {
        setState(() {
          if (insertedIndex >= 0 &&
              insertedIndex < _recentParsedDataRaw.length) {
            _recentParsedDataRaw[insertedIndex]['parsedJson'] = updated;
            _recentParsedDataRaw[insertedIndex]['title'] =
                updated['title'] ??
                _recentParsedDataRaw[insertedIndex]['title'];
            _recentParsedDataRaw[insertedIndex]['timestamp'] = DateTime.now()
                .toIso8601String();
          }
        });
        await _saveRecentScans();
      }

      setState(() {
        _statusMessage = 'Done. You can view recent scans below.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error processing image: $e';
      });
    } finally {
      textRecognizer.close();
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Open an existing saved scan
  Future<void> _openScan(int index) async {
    if (index < 0 || index >= _recentParsedDataRaw.length) return;
    final scan = _recentParsedDataRaw[index];
    final parsed = scan['parsedJson'] as Map<String, dynamic>?;

    if (parsed == null) return;

    final updated = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => TopicEditorScreen(parsedJson: parsed)),
    );

    if (updated != null) {
      setState(() {
        _recentParsedDataRaw[index]['parsedJson'] = updated;
        _recentParsedDataRaw[index]['title'] =
            updated['title'] ?? _recentParsedDataRaw[index]['title'];
        _recentParsedDataRaw[index]['timestamp'] = DateTime.now()
            .toIso8601String();
      });
      await _saveRecentScans();
    }
  }

  // Edit scan title
  Future<void> _editScanTitle(int index) async {
    final scan = _recentParsedDataRaw[index];
    final controller = TextEditingController(text: scan['title'] ?? 'Untitled');

    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Scan Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null) {
      setState(() {
        _recentParsedDataRaw[index]['title'] = newTitle;
      });
      await _saveRecentScans();
    }
  }

  void _deleteScan(int index) {
    if (index < 0 || index >= _recentParsedDataRaw.length) return;
    setState(() {
      _recentParsedDataRaw.removeAt(index);
    });
    _saveRecentScans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Image'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo),
                    label: const Text('Pick from Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_statusMessage, style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Scans',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _recentParsedDataRaw.isEmpty
                  ? const Center(child: Text('No recent scans'))
                  : ListView.builder(
                      itemCount: _recentParsedDataRaw.length,
                      itemBuilder: (context, index) {
                        final scan = _recentParsedDataRaw[index];
                        final imagePath = scan['imagePath'] as String?;
                        final title =
                            scan['title'] as String? ?? 'Untitled Scan';
                        final ts = scan['timestamp'] as String?;
                        String subtitle = ts != null
                            ? DateTime.tryParse(
                                    ts,
                                  )?.toLocal().toString().substring(0, 16) ??
                                  ''
                            : '';

                        return Card(
                          child: ListTile(
                            leading:
                                (imagePath != null &&
                                    File(imagePath).existsSync())
                                ? CircleAvatar(
                                    backgroundImage: FileImage(File(imagePath)),
                                  )
                                : const CircleAvatar(
                                    child: Icon(Icons.description),
                                  ),
                            title: Text(title),
                            subtitle: Text(subtitle),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Edit Title',
                                  onPressed: () => _editScanTitle(index),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteScan(index),
                                ),
                              ],
                            ),
                            onTap: () => _openScan(index),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
