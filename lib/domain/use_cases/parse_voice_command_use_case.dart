import '../models/parsed_command.dart';
import '../models/task.dart';

class VoiceParserUseCase {
  static final RegExp _schedulePattern = RegExp(
    r'(generate|create|make|plan|build)\s+(a |my |the )?(schedule|day|plan)',
    caseSensitive: false,
  );

  static final RegExp _taskPattern = RegExp(
    r'^(?:add|create|new task|remind me to|i need to|schedule)\s+(.+?)(?:\s+for\s+(\d{1,3})\s*(min|minute|minutes|hr|hour|hours))?(?:\s+priority\s+([1-3]))?\.?$',
    caseSensitive: false,
  );

  ParsedCommand parse(String rawTranscript) {
    final t = rawTranscript.trim();
    if (t.isEmpty) return const UnknownCommand('');

    // Check for Schedule Generation Command
    if (_schedulePattern.hasMatch(t)) {
      return const GenerateScheduleCommand();
    }

    // Check for Add Task Command
    final match = _taskPattern.firstMatch(t);
    if (match != null) {
      var titlePart = match.group(1)?.trim() ?? '';
      final numPart = match.group(2) != null ? int.tryParse(match.group(2)!) : null;
      final unitPart = match.group(3)?.toLowerCase() ?? 'min';
      final isHour = unitPart.startsWith('hr') || unitPart.startsWith('hour');
      
      final duration = numPart != null ? (isHour ? numPart * 60 : numPart) : 30;
      final priority = match.group(4) != null ? int.parse(match.group(4)!) : 2;
      final category = _pickCategory(titlePart);

      // Clean up redundant category prefix like "study calculus" -> "Calculus"
      if (category == TaskCategory.study && titlePart.toLowerCase().startsWith('study ') && titlePart.length > 6) {
        titlePart = titlePart.substring(6).trim();
      }

      // Capitalize first letter of title
      final title = titlePart.isNotEmpty
          ? '${titlePart[0].toUpperCase()}${titlePart.substring(1)}'
          : 'Untitled task';

      return AddTaskCommand(
        NewTask(
          title: title,
          category: category,
          duration: duration.clamp(5, 480),
          priority: priority,
        ),
      );
    }

    return UnknownCommand(t);
  }

  static TaskCategory _pickCategory(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'\b(class\s*rep|class|lecture|syllabus|cohort|rep)\b').hasMatch(lower)) {
      return TaskCategory.classRep;
    }
    if (RegExp(r'\b(club|president|committee|exec|treasurer|sponsor)\b').hasMatch(lower)) {
      return TaskCategory.clubPresident;
    }
    if (RegExp(r'\b(study|read|homework|assignment|revise|exam|quiz|math|physics|chem|calculus)\b').hasMatch(lower)) {
      return TaskCategory.study;
    }
    return TaskCategory.personal;
  }
}
