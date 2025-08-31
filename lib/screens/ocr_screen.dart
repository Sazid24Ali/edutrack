import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gemini_service.dart';
import 'topic_editor_screen.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _statusMessage = "Pick an image to extract text and analyze.";
  bool _isLoading = false;
  String _extractedText = "";

  List<Map<String, dynamic>> _recentParsedDataRaw = [];

  @override
  void initState() {
    super.initState();
    _loadRecentScans();
  }

  /// Load recent scans from SharedPreferences
  Future<void> _loadRecentScans() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading past scans...';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? recentScansJson = prefs.getString("recent_scans");
      if (recentScansJson != null) {
        final List<dynamic> decodedList = json.decode(recentScansJson);
        setState(() {
          _recentParsedDataRaw = decodedList
              .map((item) => item as Map<String, dynamic>)
              .toList();
          _statusMessage =
              'Loaded ${_recentParsedDataRaw.length} previous scans.';
        });
      } else {
        setState(() {
          _statusMessage = 'No previous scans found.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading recent scans: $e';
      });
      print('Error loading recent scans: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Save recent scans list
  Future<void> _saveRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("recent_scans", json.encode(_recentParsedDataRaw));
  }

  /// Pick image from source
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _isLoading = true;
        _statusMessage = "Processing image...";
      });
      await _processImage(_selectedImage!);
    }
  }

  /// Process OCR + Gemini
  Future<void> _processImage(File image) async {
    final textRecognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFile(image);
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      _extractedText = recognizedText.text.trim();
      if (_extractedText.isEmpty) {
        setState(() {
          _statusMessage = "No text found in the image.";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = "Analyzing with Gemini...";
      });

      final parsedJson = await GeminiService.parseSyllabus(_extractedText);

      if (parsedJson!.containsKey("error")) {
        setState(() {
          _statusMessage = parsedJson["error"];
          _isLoading = false;
        });
        return;
      }

      // Save to recent scans
      final scan = {
        "title": "Scan ${DateTime.now().toIso8601String()}",
        "parsedJson": parsedJson,
        "timestamp": DateTime.now().toIso8601String(),
        "imagePath": image.path,
      };
      setState(() {
        _recentParsedDataRaw.insert(0, scan);
        if (_recentParsedDataRaw.length > 10) {
          _recentParsedDataRaw = _recentParsedDataRaw.sublist(0, 10);
        }
      });
      await _saveRecentScans();

      // Navigate to editor
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TopicEditorScreen(parsedJson: parsedJson),
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = "Error processing image: $e";
        _isLoading = false;
      });
    } finally {
      textRecognizer.close();
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Delete a scan
  void _deleteScan(int index) {
    setState(() {
      _recentParsedDataRaw.removeAt(index);
    });
    _saveRecentScans();
  }

  /// Open existing scan
  void _openScan(Map<String, dynamic> scan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TopicEditorScreen(parsedJson: scan["parsedJson"]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OCR Scanner")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Capture Image"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.image),
              label: const Text("Pick from Gallery"),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const LinearProgressIndicator(),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            const Text(
              "Recent Scans",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _recentParsedDataRaw.isEmpty
                  ? const Center(child: Text("No recent scans"))
                  : ListView.builder(
                      itemCount: _recentParsedDataRaw.length,
                      itemBuilder: (context, index) {
                        final scan = _recentParsedDataRaw[index];
                        final imagePath = scan["imagePath"];
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
                            title: Text(scan["title"] ?? "Untitled Scan"),
                            subtitle: Text(
                              DateTime.parse(
                                scan["timestamp"],
                              ).toLocal().toString().substring(0, 16),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteScan(index),
                            ),
                            onTap: () => _openScan(scan),
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
