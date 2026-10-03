import '../models/parsed_command.dart';
import '../models/task.dart';

class VoiceParserUseCase {
  static final RegExp _schedulePattern = RegExp(
    r'(?:\b(?:can\s+you\s+|could\s+you\s+|would\s+you\s+|please\s+)?(?:generate|create|make|plan|build)\b\s+(?:a\s+|my\s+|the\s+)?(?:schedule|day|plan)|\bplan\s+(?:my\s+)?(?:day|schedule)\b)',
    caseSensitive: false,
  );

  static final RegExp _taskCommandPattern = RegExp(
    r'^(?:please\s+|can\s+you\s+|could\s+you\s+|would\s+you\s+|let\s+me\s+)?'
    r'(?:add|create|make|new\s+task|remind\s+me\s+to|remind\s+me\s+that\s+i\s+(?:need\s+to|have\s+to)|'
    r'don.t\s+let\s+me\s+forget\s+to|do\s+not\s+let\s+me\s+forget\s+to|'
    r'i\s+(?:need\s+to|have\s+to|should|must|want\s+to|would\s+like\s+to|plan\s+to|'
    r'am\s+supposed\s+to|m\s+supposed\s+to|promised\s+to)|need\s+to|schedule)\b',
    caseSensitive: false,
  );

  static final RegExp _implicitTaskPattern = RegExp(
    r'^(?:buy|call|email|message|text|send|submit|finish|complete|attend|prepare|'
    r'revise|study|read|write|review|book|pay|pick\s+up|collect|clean|cook|'
    r'visit|meet|exercise|work\s+out|go\s+to)\b',
    caseSensitive: false,
  );

  static final RegExp _taskExtractionPattern = RegExp(
    r'^(?:please\s+|can\s+you\s+|could\s+you\s+|would\s+you\s+|let\s+me\s+)?'
    r'(?:add|create|make|new\s+task|remind\s+me\s+to|remind\s+me\s+that\s+i\s+(?:need\s+to|have\s+to)|'
    r'don.t\s+let\s+me\s+forget\s+to|do\s+not\s+let\s+me\s+forget\s+to|'
    r'i\s+(?:need\s+to|have\s+to|should|must|want\s+to|would\s+like\s+to|plan\s+to|'
    r'am\s+supposed\s+to|m\s+supposed\s+to|promised\s+to)|need\s+to|schedule)'
    r'(?:\s+(.+))?$',
    caseSensitive: false,
  );

  static final RegExp _durationPattern = RegExp(
    r'\bfor\s+((?:\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|a|an))\s*(minute|minutes|min|mins|hour|hours|hr|hrs)\b',
    caseSensitive: false,
  );

  static final RegExp _priorityPattern = RegExp(
    r'\b(?:priority\s+)?((?:[1-3])|(high|medium|low|urgent|critical|important|whenever))\b',
    caseSensitive: false,
  );

  static final RegExp _specificTimePattern = RegExp(
    r'\bat\s+(noon|midnight|\d{1,2}(?::[0-5]\d)?\s*(?:a\.?m\.?|p\.?m\.?)?)\b',
    caseSensitive: false,
  );

  ParsedCommand parse(String rawTranscript) {
    final t = rawTranscript.trim();
    if (t.isEmpty) return const UnknownCommand('');

    final normalized = _normalizeText(t);
    if (_schedulePattern.hasMatch(normalized)) {
      return const GenerateScheduleCommand();
    }

    final taskText = _extractTaskText(normalized);
    if (taskText == null || taskText.isEmpty) {
      return UnknownCommand(t);
    }

    var remaining = taskText;
    var duration = 30;
    String? specificTime;

    final timeMatch = _specificTimePattern.firstMatch(remaining);
    if (timeMatch != null) {
      final parsedTime = _parseSpecificTime(timeMatch.group(1)!);
      if (parsedTime != null) {
        specificTime = parsedTime;
        remaining =
            '${remaining.substring(0, timeMatch.start)} ${remaining.substring(timeMatch.end)}'
                .trim();
      }
    }

    final durationMatch = _durationPattern.firstMatch(remaining);
    if (durationMatch != null) {
      final valueText = durationMatch.group(1)?.trim() ?? '30';
      final unitText = durationMatch.group(2)?.toLowerCase() ?? 'min';
      duration = _durationToMinutes(_parseDurationValue(valueText), unitText);
      remaining =
          '${remaining.substring(0, durationMatch.start)} ${remaining.substring(durationMatch.end)}'
              .trim();
    }

    var priority = 2;
    final priorityMatch = _priorityPattern.firstMatch(remaining);
    if (priorityMatch != null) {
      final rawPriority = priorityMatch.group(1)?.toLowerCase() ?? '2';
      priority = _parsePriority(rawPriority);
      remaining =
          '${remaining.substring(0, priorityMatch.start)} ${remaining.substring(priorityMatch.end)}'
              .trim();
    }

    var titlePart = remaining
        .replaceAll(RegExp(r'[.,!?]+$'), '')
        .replaceAll(RegExp(r'^(?:to\s+|a\s+|an\s+|the\s+|my\s+)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (titlePart.isEmpty) return UnknownCommand(t);

    final category = _pickCategory(titlePart);
    if (category == TaskCategory.study &&
        titlePart.toLowerCase().startsWith('study ') &&
        titlePart.length > 6) {
      titlePart = titlePart.substring(6).trim();
    }

    if (titlePart.isEmpty) return UnknownCommand(t);

    final title = titlePart[0].toUpperCase() + titlePart.substring(1);

    return AddTaskCommand(
      NewTask(
        title: title,
        category: category,
        duration: duration.clamp(5, 480),
        priority: priority,
        specificTime: specificTime,
      ),
    );
  }

  static String _normalizeText(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String? _extractTaskText(String text) {
    if (_taskCommandPattern.hasMatch(text)) {
      final match = _taskExtractionPattern.firstMatch(text);
      final captured = match?.group(1)?.trim() ?? '';
      return captured.isEmpty ? null : captured;
    }
    return _implicitTaskPattern.hasMatch(text) ? text : null;
  }

  static int _durationToMinutes(double value, String unit) {
    final isHour = unit.startsWith('h') || unit.startsWith('hr');
    return (isHour ? value * 60 : value).round();
  }

  static double _parseDurationValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return 30;

    final decimalValue = double.tryParse(normalized);
    if (decimalValue != null) return decimalValue;

    final wordValues = {
      'a': 1,
      'an': 1,
      'zero': 0,
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'eleven': 11,
      'twelve': 12,
      'thirteen': 13,
      'fourteen': 14,
      'fifteen': 15,
      'sixteen': 16,
      'seventeen': 17,
      'eighteen': 18,
      'nineteen': 19,
      'twenty': 20,
      'thirty': 30,
      'forty': 40,
      'fifty': 50,
      'sixty': 60,
      'seventy': 70,
      'eighty': 80,
      'ninety': 90,
    };

    if (wordValues.containsKey(normalized)) {
      return wordValues[normalized]!.toDouble();
    }

    if (normalized.contains('half')) {
      return 0.5;
    }

    return 30;
  }

  static int _parsePriority(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'high' ||
        normalized == 'urgent' ||
        normalized == 'critical' ||
        normalized == 'important') {
      return 1;
    }
    if (normalized == 'medium') return 2;
    if (normalized == 'low' || normalized == 'whenever') return 3;
    return int.tryParse(normalized) ?? 2;
  }

  static String? _parseSpecificTime(String value) {
    final normalized = value.toLowerCase().replaceAll('.', '').trim();
    if (normalized == 'noon') return '12:00';
    if (normalized == 'midnight') return '00:00';

    final match = RegExp(r'^(\d{1,2})(?::([0-5]\d))?\s*(am|pm)?$')
        .firstMatch(normalized);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '0');
    final meridiem = match.group(3);
    if (meridiem == null && hour < 13 && !normalized.contains(':')) {
      return null;
    }
    if (hour > 23 || (meridiem != null && (hour < 1 || hour > 12))) {
      return null;
    }
    if (meridiem == 'pm' && hour != 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static TaskCategory _pickCategory(String text) {
    final lower = text.toLowerCase();
    if (RegExp(
            r'\b(class\s*rep|class|lecture|lecturer|professor|teacher|syllabus|cohort|rep|seminar)\b')
        .hasMatch(lower)) {
      return TaskCategory.classRep;
    }
    if (RegExp(
            r'\b(club|president|committee|exec|treasurer|sponsor|budget|meeting)\b')
        .hasMatch(lower)) {
      return TaskCategory.clubPresident;
    }
    if (RegExp(
            r'\b(study|read|homework|assignment|revise|exam|quiz|math|physics|chem|calculus|coursework)\b')
        .hasMatch(lower)) {
      return TaskCategory.study;
    }
    if (RegExp(r'\b(work|office|client|report|project|interview)\b')
        .hasMatch(lower)) {
      return TaskCategory.work;
    }
    if (RegExp(r'\b(gym|exercise|workout|doctor|health|medicine|run)\b')
        .hasMatch(lower)) {
      return TaskCategory.health;
    }
    if (RegExp(r'\b(shop|shopping|groceries|errand|pickup|pick up)\b')
        .hasMatch(lower)) {
      return TaskCategory.errands;
    }
    if (RegExp(
      r'\b(family|parent|sibling|brother|sister|mom|mum|dad|mother|father|child|kids)\b',
    ).hasMatch(lower)) {
      return TaskCategory.family;
    }
    if (RegExp(r'\b(budget|bill|rent|payment|bank|finance)\b')
        .hasMatch(lower)) {
      return TaskCategory.finance;
    }
    if (RegExp(r'\b(friend|friends|social|party|dinner|hang out)\b')
        .hasMatch(lower)) {
      return TaskCategory.social;
    }
    return TaskCategory.personal;
  }
}
