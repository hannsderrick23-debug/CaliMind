import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:calimind/core/network/supabase_client.dart';
import 'package:calimind/domain/models/parsed_command.dart';
import 'package:calimind/domain/models/task.dart';

class GroqService {
  final http.Client _client;

  GroqService({http.Client? client}) : _client = client ?? http.Client();

  /// Transcribe audio through the authenticated Supabase Edge Function.
  Future<String?> transcribeAudio(String audioFilePath) async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session == null) {
      debugPrint('GroqService: Sign-in is required for cloud transcription');
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
        Uri.parse('${SupabaseConfig.url}/functions/v1/groq'),
      )
        ..headers['apikey'] = SupabaseConfig.publishableKey
        ..headers['Authorization'] = 'Bearer ${session.accessToken}'
        ..fields['action'] = 'transcribe';
      request.files
          .add(await http.MultipartFile.fromPath('file', audioFilePath));

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) {
        debugPrint(
          'Groq Edge Function transcription error '
          '${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['text'] as String?)?.trim();
    } catch (error) {
      debugPrint('Groq Edge Function transcription request failed: $error');
      return null;
    }
  }

  /// Parse natural voice speech through the authenticated Supabase function.
  Future<ParsedCommand?> parseVoiceCommandWithAI(
    String transcript, {
    String? currentFocusRole,
    DateTime? referenceDateTime,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'groq',
        body: {
          'action': 'parse',
          'transcript': transcript,
          'current_focus_role': currentFocusRole,
          'reference_date_time':
              (referenceDateTime ?? DateTime.now()).toIso8601String(),
        },
      );

      if (response.status < 200 || response.status >= 300) {
        debugPrint(
          'Groq Edge Function parsing error '
          '${response.status}: ${response.data}',
        );
        return null;
      }

      final data = response.data;
      if (data is! Map) return null;
      final parsedJson = Map<String, dynamic>.from(data);

      final commandType = parsedJson['command_type'] as String?;
      if (commandType == 'generate_schedule') {
        return const GenerateScheduleCommand();
      }
      if (commandType == 'unknown') {
        return UnknownCommand(transcript);
      }

      if (commandType != 'add_task') return null;
      final taskData = parsedJson['task'];
      if (taskData is! Map) return null;
      final task = Map<String, dynamic>.from(taskData);

      final rawCategory = task['category'] as String? ?? 'personal';
      final category = switch (rawCategory.toLowerCase()) {
        'study' => TaskCategory.study,
        'class_rep' => TaskCategory.classRep,
        'club_president' => TaskCategory.clubPresident,
        'work' => TaskCategory.work,
        'health' || 'health & fitness' => TaskCategory.health,
        'errands' => TaskCategory.errands,
        'family' => TaskCategory.family,
        'finance' => TaskCategory.finance,
        'social' => TaskCategory.social,
        _ => TaskCategory.personal,
      };

      final rawPreferredTime = task['preferred_time'] as String?;
      final preferredTime = switch (rawPreferredTime?.toLowerCase()) {
        'morning' => PreferredTime.morning,
        'afternoon' => PreferredTime.afternoon,
        'evening' => PreferredTime.evening,
        _ => null,
      };
      final deadline = DateTime.tryParse(task['deadline'] as String? ?? '');
      final reminderAt =
          DateTime.tryParse(task['reminder_at'] as String? ?? '');
      final duration = (task['duration_minutes'] as num?)?.toInt() ?? 30;
      final priority = (task['priority'] as num?)?.toInt() ?? 2;
      final title = task['title'] as String? ?? transcript;

      return AddTaskCommand(
        NewTask(
          title: title.isNotEmpty ? title : 'Untitled Task',
          category: category,
          duration: duration.clamp(5, 480),
          priority: priority.clamp(1, 3),
          specificTime: task['specific_time'] as String?,
          preferredTime: preferredTime,
          deadline: deadline,
          reminderAt: reminderAt,
        ),
      );
    } catch (error) {
      debugPrint('Groq Edge Function parsing request failed: $error');
      return null;
    }
  }
}
