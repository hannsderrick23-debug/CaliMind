import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:calimind/domain/models/parsed_command.dart';
import 'package:calimind/domain/models/task.dart';

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _transcriptionModel = 'whisper-large-v3-turbo';
  static const String _chatModel = 'llama-3.3-70b-versatile';
  static const String _storageKey = 'groq_api_key';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final http.Client _client;

  GroqService({http.Client? client}) : _client = client ?? http.Client();

  /// Retrieve the active Groq API Key from secure storage or fallback
  Future<String?> getApiKey() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (e) {
      debugPrint('Failed reading Groq API key from secure storage: $e');
    }

    // Optional environment fallback if configured
    const envKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty) return envKey;

    return null;
  }

  /// Store the Groq API Key securely
  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _storageKey, value: apiKey.trim());
  }

  /// Clear the stored Groq API Key
  Future<void> clearApiKey() async {
    await _storage.delete(key: _storageKey);
  }

  /// Transcribe audio file using Groq Whisper Large v3
  Future<String?> transcribeAudio(String audioFilePath) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('GroqService: No API key available for transcription');
      return null;
    }

    final file = File(audioFilePath);
    if (!await file.exists()) {
      debugPrint('GroqService: Audio file does not exist at $audioFilePath');
      return null;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';
      request.fields['model'] = _transcriptionModel;
      request.fields['temperature'] = '0.0';
      request.fields['response_format'] = 'json';
      request.fields['prompt'] =
          'Task management, daily schedule, study, calculus, physics, class rep, club president, priority, deadline';

      request.files.add(
        await http.MultipartFile.fromPath('file', audioFilePath),
      );

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = data['text'] as String?;
        return text?.trim();
      } else {
        debugPrint(
            'Groq transcription error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Groq transcription request failed: $e');
      return null;
    }
  }

  /// Parse natural voice speech into a structured CaliMind command using Groq LLaMA 3.3
  Future<ParsedCommand?> parseVoiceCommandWithAI(
    String transcript, {
    String? currentFocusRole,
    DateTime? referenceDateTime,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final refDate = referenceDateTime ?? DateTime.now();

    final systemPrompt = '''
You are the natural language parser for CaliMind, an intelligent daily task planner for multi-role students (Class Rep, Club President, Academics/Study, Personal).
Current date & time: ${refDate.toIso8601String()}.
Current focus role context: ${currentFocusRole ?? 'All'}.

Extract the user's intent into strict JSON with the schema:
{
  "command_type": "add_task" | "generate_schedule" | "unknown",
  "task": {
    "title": "Clean concise task title without redundant prefixes",
    "category": "study" | "class_rep" | "club_president" | "personal",
    "duration_minutes": integer (default 30),
    "priority": integer (1 = high, 2 = medium, 3 = low, default 2),
    "specific_time": "HH:mm" in 24hr format or null,
    "preferred_time": "morning" | "afternoon" | "evening" | null,
    "deadline": "ISO-8601 string or null"
  }
}

Rules:
- If user asks to plan day, build/create schedule, set "command_type": "generate_schedule".
- For tasks, identify category accurately:
  * "class_rep": lectures, class announcements, cohort issues, faculty meetings, lecture reps
  * "club_president": club meetings, budgets, executive team, sponsor calls, events
  * "study": revising, exams, homework, math, physics, reading, calculus, labs
  * "personal": groceries, gym, errands, rest, laundry
- Return valid JSON only, no markdown formatting.
''';

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _chatModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': transcript},
          ],
          'temperature': 0.1,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Groq Chat error ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final messageContent = choices.first['message']['content'] as String;
      final parsedJson = jsonDecode(messageContent) as Map<String, dynamic>;

      final commandType = parsedJson['command_type'] as String?;
      if (commandType == 'generate_schedule') {
        return const GenerateScheduleCommand();
      }

      if (commandType == 'add_task') {
        final taskData = parsedJson['task'] as Map<String, dynamic>?;
        if (taskData == null) return null;

        final rawCat = taskData['category'] as String? ?? 'personal';
        final category = switch (rawCat.toLowerCase()) {
          'study' => TaskCategory.study,
          'class_rep' => TaskCategory.classRep,
          'club_president' => TaskCategory.clubPresident,
          _ => TaskCategory.personal,
        };

        final rawPref = taskData['preferred_time'] as String?;
        final preferredTime = switch (rawPref?.toLowerCase()) {
          'morning' => PreferredTime.morning,
          'afternoon' => PreferredTime.afternoon,
          'evening' => PreferredTime.evening,
          _ => null,
        };

        DateTime? deadline;
        final rawDeadline = taskData['deadline'] as String?;
        if (rawDeadline != null) {
          deadline = DateTime.tryParse(rawDeadline);
        }

        final duration = (taskData['duration_minutes'] as num?)?.toInt() ?? 30;
        final priority = (taskData['priority'] as num?)?.toInt() ?? 2;
        final title = taskData['title'] as String? ?? transcript;

        return AddTaskCommand(
          NewTask(
            title: title.isNotEmpty ? title : 'Untitled Task',
            category: category,
            duration: duration.clamp(5, 480),
            priority: priority.clamp(1, 3),
            specificTime: taskData['specific_time'] as String?,
            preferredTime: preferredTime,
            deadline: deadline,
          ),
        );
      }

      return null;
    } catch (e) {
      debugPrint('Groq AI command parsing error: $e');
      return null;
    }
  }
}
