import 'package:isar/isar.dart';

part 'task.g.dart';

enum TaskStatus {
  pending,
  completed,
  failed,
}

@collection
class Task {
  Id id = Isar.autoIncrement;
  String prompt = '';
  List<String> thoughts = []; // Store reasoning thoughts
  List<String> steps = [];

  @enumerated
  TaskStatus status = TaskStatus.pending;

  @Deprecated('Use status field instead')
  bool completed = false;

  DateTime createdAt = DateTime.now();

  // Helper getters for backward compatibility
  bool get isCompleted => status == TaskStatus.completed;
  bool get isFailed => status == TaskStatus.failed;
  bool get isPending => status == TaskStatus.pending;
}
