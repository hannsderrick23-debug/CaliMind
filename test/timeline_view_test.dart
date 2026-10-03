import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/views/schedule/widgets/grid_view.dart';
import 'package:calimind/presentation/views/schedule/widgets/timeline_view.dart';

void main() {
  testWidgets('timeline task card uses readable dark text on a light card',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineView(
            slots: [
              ScheduleSlot(
                taskId: 'task-1',
                taskTitle: 'Review calculus notes',
                category: TaskCategory.study,
                startTime: '09:00',
                endTime: '09:45',
                duration: 45,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Review calculus notes'));
    final startTime = tester.widget<Text>(find.text('09:00'));

    expect(title.style?.color, CaliMindColors.foreground);
    expect(startTime.style?.color, CaliMindColors.foreground);
  });

  testWidgets('schedule grid stays empty when there are no real slots',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScheduleGridView(slots: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Free'), findsNWidgets(4));
    expect(find.text('Cohort lecture notes distribution'), findsNothing);
    expect(find.text('Club sponsorship proposal review'), findsNothing);
  });
}
