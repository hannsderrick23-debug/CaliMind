import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/core/services/aventor_eye_service.dart';

void main() {
  group('AventorEyeInsight.fromJson', () {
    test('decodes a valid insight', () {
      final insight = AventorEyeInsight.fromJson({
        'kind': 'focus',
        'title': 'Start with one task',
        'message': 'Your first priority has room in the morning.',
      });

      expect(insight.kind, AventorEyeInsightKind.focus);
      expect(insight.title, 'Start with one task');
      expect(insight.message, 'Your first priority has room in the morning.');
    });

    test('rejects an unsupported insight kind', () {
      expect(
        () => AventorEyeInsight.fromJson({
          'kind': 'pressure',
          'title': 'Do it now',
          'message': 'You must finish everything today.',
        }),
        throwsFormatException,
      );
    });

    test('rejects insight text beyond the display limits', () {
      expect(
        () => AventorEyeInsight.fromJson({
          'kind': 'focus',
          'title': 'x' * 46,
          'message': 'A reasonable message.',
        }),
        throwsFormatException,
      );
    });
  });
}
