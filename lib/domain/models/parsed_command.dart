import 'task.dart';

sealed class ParsedCommand {
  const ParsedCommand();
}

class AddTaskCommand extends ParsedCommand {
  final NewTask task;
  const AddTaskCommand(this.task);
}

class GenerateScheduleCommand extends ParsedCommand {
  const GenerateScheduleCommand();
}

class UnknownCommand extends ParsedCommand {
  final String transcript;
  const UnknownCommand(this.transcript);
}
