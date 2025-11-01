import 'package:isar/isar.dart';

part 'task.g.dart';

@collection
class Task {
  Id id = Isar.autoIncrement;
  String prompt = '';
  List<String> thoughts = []; // Store reasoning thoughts
  List<String> steps = [];
  bool completed = false;
  DateTime createdAt = DateTime.now();
}

