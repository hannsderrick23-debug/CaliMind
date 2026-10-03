import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/views/schedule/widgets/month_calendar_view.dart';

Task _taskOnJuneSecond() => Task(
      id: 'task-1',
      userId: 'test-user',
      title: 'Prepare class notes',
      category: TaskCategory.study,
      duration: 45,
      deadline: DateTime(2026, 6, 2),
      priority: 1,
      completed: false,
      createdAt: DateTime(2026, 5, 20),
      updatedAt: DateTime(2026, 5, 20),
    );

void main() {
  testWidgets('month calendar selects a day and summarizes its activities',
      (tester) async {
    DateTime? selectedDate;
    var monthChange = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendarView(
            month: DateTime(2026, 6),
            selectedDate: DateTime(2026, 6, 2),
            tasks: [_taskOnJuneSecond()],
            scheduledSlots: const [
              ScheduleSlot(
                taskId: 'task-1',
                taskTitle: 'Prepare class notes',
                category: TaskCategory.study,
                startTime: '10:00',
                endTime: '10:45',
                duration: 45,
                scheduleDate: '2026-06-02',
              ),
            ],
            onDateSelected: (date) => selectedDate = date,
            onMonthChanged: (offset) => monthChange = offset,
          ),
        ),
      ),
    );

    expect(find.text('June 2026'), findsOneWidget);
    expect(find.text('1 task  ·  1 scheduled block'), findsOneWidget);
    expect(find.text('Prepare class notes'), findsOneWidget);

    await tester.tap(find.text('2'));
    expect(selectedDate, DateTime(2026, 6, 2));

    await tester.tap(find.byTooltip('Next month'));
    expect(monthChange, 1);
  });
}
