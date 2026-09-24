import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/task.dart';

// null = 'All', otherwise a specific TaskCategory
final roleFocusProvider = StateProvider<TaskCategory?>((ref) => null);
