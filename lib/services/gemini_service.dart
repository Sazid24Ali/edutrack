// lib/gemini/gemini_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math'; // For min function
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// import '../models/syllabus_analyzer_models.dart';
// import '../utils/syllabus_calculator.dart';

class GeminiService {
  static String _cleanJsonMarkdown(String rawResponse) {
    final cleaned = rawResponse.trim();
    if (cleaned.startsWith('```json') && cleaned.endsWith('```')) {
      return cleaned
          .substring('```json'.length, cleaned.length - '```'.length)
          .trim();
    }
    if (cleaned.startsWith('```') && cleaned.endsWith('```')) {
      return cleaned
          .substring('```'.length, cleaned.length - '```'.length)
          .trim();
    }
    return cleaned;
  }

  static Future<Map<String, dynamic>?> parseSyllabus(
    String syllabusText,
  ) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY not found in .env. Please add it to your .env file.',
      );
    }

    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey';

    // MODIFIED PROMPT BELOW
    final prompt =
        """
You are an expert academic syllabus analyzer AI.

Your task is to meticulously parse the following OCR text of a course syllabus.
The OCR text might contain errors, so use your best judgment to interpret the content.

Extract the following information and provide it as a **strictly valid JSON** structure with this hierarchical format:

{
  "is_syllabus": true,
  "total_estimated_time_for_syllabus": 0,
  "course_title": "string",
  "course_code": "string",
  "instructor": "string",
  "semester": "string",
  "year": "integer",
  "learning_objectives": [
    "string"
  ],
  "grading_breakdown": {
    "assignment_type_1": "percentage_or_description"
  },
  "weekly_schedule": [
    {
      "week_number": "integer",
      "topic": "string",
      "subtopics": [
        // recursively nested Topic objects
      ],
      "estimated_time": 0,
      "importance": 3,
      "difficulty": 3,
      "readings": ["string"],
      "assignments": ["string"],
      "web_search_keywords": ["string"],
      "suggested_resources": ["string"]
    }
  ],
  "required_materials": ["string"],
  "important_dates": [
    {"event": "string", "date": "string (YYYY-MM-DD format if possible)"}
  ],
  "contact_information": {
    "email": "string",
    "office_hours": "string",
    "other_details": "string"
  },
  "notes_or_disclaimers": "string"
}

### IMPORTANT INSTRUCTIONS FOR GENERATING JSON:

1.  **Hierarchy Preservation:**
    -   Detect units, topics, and subtopics **strictly based on visual cues**: indentation, bullets, numbered lists, line breaks.
    -   NEVER club multiple concepts or subtopics into one. When in doubt, parse as separate nested subtopics.

2.  **Estimated Time Calculation:**
    -   If the syllabus explicitly states time for a topic (e.g., "(60 mins)", "2 hours"), use that exact numerical value in minutes.
    -   If time is NOT explicitly stated for a topic, you **MUST estimate realistically based on the topic's perceived complexity, depth, and typical university course pacing**.
    -   **CRITICAL: NEVER assign 0 minutes to an estimated_time if it's a valid topic.** If you cannot find an explicit time, you **MUST infer a reasonable positive duration** (e.g., 15, 30, 45, 60, 90, 120 minutes). Choose the smallest reasonable duration if uncertain.
    -   **For EVERY** estimated_time that you infer (i.e., not explicitly stated in the syllabus), you **MUST** include a clear `"time_reasoning"` explaining your logic (e.g., "Estimated 45 minutes based on topic complexity for a standard university course. No explicit time found.").
    -   The `total_estimated_time` for each unit and `total_estimated_time_for_syllabus` should be accurate sums of all child topics/subtopics. (This will be calculated client-side, but it's a good reminder for Gemini).

3.  **Realistic Inference for Importance/Difficulty (Revised Directive for balanced distribution):**
    - For 'importance' and 'difficulty', **infer the most appropriate integer value (1-5) based on the topic's content, complexity, and common academic understanding of typical course material.**
    - **Crucially, strive for a realistic distribution across the 1-5 scale.** Not all topics are equally important or difficult.
        - Use **1-2** for foundational, introductory, or simpler review topics.
        - Use **3** for standard, average complexity topics.
        - Use **4-5** for core concepts, challenging topics, or highly critical areas.
    - The goal is to provide varied values that help a student prioritize effectively for study. **Only use a default of 3 if absolutely no reasonable inference can be made from the text.**

4.  **Output Format:**
    -   Your response MUST be a **plain JSON string**, without any markdown code blocks (e.g., no ```json ```).
    -   Ensure all numeric fields are actual **integers**, not strings.
    -   Ensure boolean fields are `true` or `false`, not "true"/"false".
    -   For list fields like `learning_objectives`, `readings`, `assignments`, `web_search_keywords`, `suggested_resources`, `required_materials`, `important_dates`, **ONLY include them if they have actual content**. If they are empty, OMIT the key entirely instead of including an empty array (`[]`). This will help keep JSON size manageable.
    -   Use consistent field names **exactly** as described in the JSON structure above.

5.  **Course Title and Code Extraction (Revised Directive):**
    - **CRITICAL**: The `course_title` and `course_code` are usually found at the **very beginning or top section** of the syllabus. Look for explicit labels like "Course Title:", "Subject Name:", "Course Name:", "Title:", "Course Code:", "Subject Code:", or any prominent text that clearly identifies the course.
    - For `course_code`, look for concise alphanumeric identifiers, often containing dashes, spaces, or numbers (e.g., "CS101", "MATH-203", "AI-F2024", "BIO 301").
    - **Prioritize extracting these fields accurately. If a clear title or code is not explicitly labeled, infer the most prominent and relevant text at the top of the document.**

**OCR Syllabus Text to Analyze:**
$syllabusText

""";
    // END MODIFIED PROMPT

    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
      "generationConfig": {
        "temperature": 0.1, // Keep low for deterministic output
        "topP": 0.1,
        "topK": 1,
      },
    };

    try {
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({'Content-Type': 'application/json'});
      request.body = jsonEncode(body);

      final streamedResponse = await request.send();

      // Collect streamed chunks
      final responseBodyChunks = <List<int>>[];
      await for (var chunk in streamedResponse.stream) {
        responseBodyChunks.add(chunk);
      }
      final fullResponseBody = utf8.decode(
        responseBodyChunks.expand((x) => x).toList(),
      );

      if (streamedResponse.statusCode == 200) {
        if (fullResponseBody.isEmpty) {
          print('Gemini API: Response body is empty for status 200.');
          throw Exception('Gemini API: Empty response body received.');
        }

        Map<String, dynamic> jsonResponse;
        try {
          jsonResponse = json.decode(fullResponseBody); // Use full body
        } catch (e) {
          print(
            'Gemini API: Failed to decode response body as JSON. Error: $e',
          );
          print(
            'Gemini API: Received body:\n$fullResponseBody',
          ); // Print full body on decode error
          throw Exception(
            'Gemini API: Invalid JSON received: ${fullResponseBody.substring(0, min(fullResponseBody.length, 200))}...',
          );
        }

        final List<dynamic>? candidates = jsonResponse['candidates'];
        if (candidates == null || candidates.isEmpty) {
          print('Gemini API: No candidates found in response.');
          if (jsonResponse['promptFeedback'] != null) {
            print(
              'Gemini API: Prompt Feedback: ${jsonResponse['promptFeedback']}',
            );
            if (jsonResponse['promptFeedback']['safetyRatings'] != null) {
              print(
                'Gemini API: Safety Ratings: ${jsonResponse['promptFeedback']['safetyRatings']}',
              );
              throw Exception(
                'Gemini API: Content potentially blocked due to safety concerns.',
              );
            }
          }
          throw Exception(
            'Gemini API: Response missing expected "candidates" or it is empty.',
          );
        }

        final Map<String, dynamic>? firstCandidate = candidates[0];
        if (firstCandidate == null ||
            firstCandidate['content'] == null ||
            firstCandidate['content']['parts'] == null) {
          print(
            'Gemini API: First candidate or its content/parts is null/malformed.',
          );
          print('Gemini API: First candidate JSON: $firstCandidate');
          throw Exception(
            'Gemini API: Response structure for content missing in first candidate.',
          );
        }

        final List<dynamic>? parts = firstCandidate['content']['parts'];
        if (parts == null || parts.isEmpty) {
          print('Gemini API: Parts list is null or empty in first candidate.');
          throw Exception(
            'Gemini API: Response missing expected "parts" or it is empty.',
          );
        }

        final String? rawGeminiText = parts[0]?['text'];
        String cleanText = ''; // Declare cleanText at a higher scope

        if (rawGeminiText != null && rawGeminiText.isNotEmpty) {
          cleanText = _cleanJsonMarkdown(rawGeminiText); // Assign value here

          print('DEBUG: Cleaned JSON from Gemini for parsing:\n$cleanText');

          // --- SAVE RAW RESPONSE TO FILE FOR DEBUGGING ---
          try {
            var status = await Permission.storage.request();
            if (status.isGranted ||
                (Platform.isAndroid &&
                    (await Permission.storage.status).isGranted) ||
                Platform.isIOS) {
              final directory = await getApplicationDocumentsDirectory();
              final file = File('${directory.path}/gemini_raw_response.json');
              await file.writeAsString(fullResponseBody);
              print('DEBUG: Gemini raw response saved to: ${file.path}');
              print('DEBUG: Please inspect this file to see the full JSON.');
            } else {
              print(
                'DEBUG: Storage permission denied or not required. Cannot save raw response to file. '
                'For Android 10+ and iOS, files usually go to app-specific dirs without explicit "storage" permission pop-up. '
                'You might still find it in device file explorer at /Android/data/YOUR_PACKAGE_NAME/files/',
              );
            }
          } catch (e) {
            print('DEBUG: Error saving raw response to file: $e');
          }
          // --- END NEW: SAVE RAW RESPONSE TO FILE ---

          final Map<String, dynamic> parsedJson = json.decode(cleanText);
          // final SyllabusAnalysisResponse syllabusResponse =
          //     SyllabusAnalysisResponse.fromJson(parsedJson);

          // SyllabusCalculator.calculateAllTotals(syllabusResponse);

          // return syllabusResponse;
          return parsedJson;
        } else {
          print('Gemini API returned an empty or null response text part.');
          return null;
        }
      } else {
        print(
          'Gemini API request failed with status: ${streamedResponse.statusCode}',
        );
        print('Response body for failed request: $fullResponseBody');
        throw Exception(
          'Failed to analyze syllabus: ${streamedResponse.statusCode} - ${fullResponseBody.substring(0, min(fullResponseBody.length, 200))}...',
        );
      }
    } catch (e) {
      if (e.toString().contains("503")) {
        // Server overloaded
        throw Exception(
          "Gemini is busy right now. Please try again in a few seconds.",
        );
      } else {
        // Generic error
        throw Exception("Failed to analyze syllabus: $e");
      }
      rethrow;
    }
  }
}
