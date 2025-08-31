import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScanStorage {
  static const String _key = "saved_scans";

  // Save scan
  static Future<void> saveScan(Map<String, dynamic> scan) async {
    final prefs = await SharedPreferences.getInstance();
    final scans = prefs.getStringList(_key) ?? [];
    scans.add(jsonEncode(scan));
    await prefs.setStringList(_key, scans);
  }

  // Load all scans
  static Future<List<Map<String, dynamic>>> loadScans() async {
    final prefs = await SharedPreferences.getInstance();
    final scans = prefs.getStringList(_key) ?? [];
    return scans.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  // Update scan by id
  static Future<void> updateScan(
    String id,
    Map<String, dynamic> updatedScan,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final scans = prefs.getStringList(_key) ?? [];
    final updated = scans.map((s) {
      final scan = jsonDecode(s) as Map<String, dynamic>;
      return scan["id"] == id ? jsonEncode(updatedScan) : s;
    }).toList();
    await prefs.setStringList(_key, updated);
  }

  // Delete scan
  static Future<void> deleteScan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final scans = prefs.getStringList(_key) ?? [];
    scans.removeWhere((s) {
      final scan = jsonDecode(s) as Map<String, dynamic>;
      return scan["id"] == id;
    });
    await prefs.setStringList(_key, scans);
  }
}
