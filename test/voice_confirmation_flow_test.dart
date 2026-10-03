import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/core/services/groq_service.dart';
import 'package:calimind/data/datasources/task_remote_datasource.dart';
import 'package:calimind/data/repositories/task_repository_impl.dart';
import 'package:calimind/domain/models/parsed_command.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/state/voice_assistant_provider.dart';
import 'package:calimind/presentation/views/tasks/widgets/voice_confirm_sheet.dart';

class FakeTaskDatasource implements TaskRemoteDatasource {
  final List<Task> tasks = [];

  @override
  Future<List<Task>> fetchTasks({int? retentionDays}) async => tasks;

  @override
  Future<Task> createTask(NewTask newTask) async {
    final created = Task(
      id: 'task-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'test-user',
      title: newTask.title,
      description: newTask.description,
      category: newTask.category,
      duration: newTask.duration,
      deadline: newTask.deadline,
      preferredTime: newTask.preferredTime,
      specificTime: newTask.specificTime,
      priority: newTask.priority,
      completed: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    tasks.insert(0, created);
    return created;
  }

  @override
  Future<Task> updateTask(Task task) async => task;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<Task> toggleTaskCompletion(String id, bool completed) async {
    final task = tasks.firstWhere((t) => t.id == id);
    final updated = task.copyWith(
        completed: completed, completedAt: completed ? DateTime.now() : null);
    final index = tasks.indexWhere((t) => t.id == id);
    tasks[index] = updated;
    return updated;
  }

  @override
  Future<int> purgeCompletedTasks(int retentionDays) async => 0;
}

class FakeGroqService extends GroqService {
  ParsedCommand? result;
  String? submittedTranscript;

  @override
  Future<ParsedCommand?> parseVoiceCommandWithAI(
    String transcript, {
    String? currentFocusRole,
    DateTime? referenceDateTime,
  }) async {
    submittedTranscript = transcript;
    return result;
  }
}

void main() {
  test('task datasource refuses to claim a task was saved without Supabase',
      () async {
    await expectLater(
      TaskRemoteDatasourceImpl().createTask(
        const NewTask(
          title: 'Save to database',
          category: TaskCategory.personal,
          duration: 30,
          priority: 2,
        ),
      ),
      throwsStateError,
    );
  });

  test('voice transcript is sent to AI before an unknown response is shown',
      () async {
    final groq = FakeGroqService()..result = const UnknownCommand('Thank you');
    final notifier = VoiceAssistantNotifier(groq: groq);

    await notifier.processTranscript('Thank you');

    expect(groq.submittedTranscript, 'Thank you');
    expect(notifier.state.usedAiParser, isTrue);
    expect(notifier.state.draftTask, isNull);
    expect(notifier.state.errorMessage, contains('I heard “Thank you”'));
    notifier.dispose();
  });

  test('AI structured task fields populate the voice review draft', () async {
    final groq = FakeGroqService()
      ..result = const AddTaskCommand(
        NewTask(
          title: 'Study calculus',
          category: TaskCategory.study,
          duration: 45,
          priority: 1,
          specificTime: '15:30',
        ),
      );
    final notifier = VoiceAssistantNotifier(groq: groq);

    await notifier.processTranscript(
      'Please study calculus for 45 minutes at 3:30 pm, high priority',
    );

    expect(groq.submittedTranscript,
        'Please study calculus for 45 minutes at 3:30 pm, high priority');
    expect(notifier.state.draftTask?.title, 'Study calculus');
    expect(notifier.state.draftTask?.category, TaskCategory.study);
    expect(notifier.state.draftTask?.duration, 45);
    expect(notifier.state.draftTask?.priority, 1);
    expect(notifier.state.draftTask?.specificTime, '15:30');
    notifier.dispose();
  });

  test('dismiss clears a voice draft before the next capture', () {
    final notifier = VoiceAssistantNotifier()
      ..state = const VoiceAssistantState(
        finalTranscript: 'Study calculus',
        draftTask: NewTask(
          title: 'Study calculus',
          category: TaskCategory.study,
          duration: 45,
          priority: 1,
        ),
      );

    notifier.dismiss();

    expect(notifier.state.draftTask, isNull);
    expect(notifier.state.parsedCommand, isNull);
    expect(notifier.state.finalTranscript, isEmpty);
    notifier.dispose();
  });

  testWidgets('voice confirmation card appears and confirms a parsed task',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeDatasource = FakeTaskDatasource();
    final fakeRepo = TaskRepositoryImpl(datasource: fakeDatasource);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final container =
                  ProviderScope.containerOf(context, listen: false);
              container.read(voiceAssistantProvider.notifier).state =
                  const VoiceAssistantState(
                draftTask: NewTask(
                  title: 'Study calculus',
                  category: TaskCategory.study,
                  duration: 45,
                  priority: 1,
                ),
              );
            });

            return MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, child) {
                    final task = ref.watch(voiceAssistantProvider).draftTask;
                    if (task == null) {
                      return const SizedBox.shrink();
                    }
                    return VoiceConfirmSheet(
                      onConfirmed: () {},
                      onDismissed: () {},
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Review your request'), findsOneWidget);
    expect(find.text('Review & confirm before saving'), findsOneWidget);
    expect(find.text('Study calculus'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Study calculus chapter 2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
    await tester.pumpAndSettle();

    expect(fakeDatasource.tasks, isNotEmpty);
    expect(fakeDatasource.tasks.first.title, 'Study calculus chapter 2');
  });
}
