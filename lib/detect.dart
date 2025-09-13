import 'dart:io';

import 'package:ai_automation_app/main.dart';

Future<void> main(List<String> args) async {
  final image = File("./screeshot.png").readAsBytesSync();
  final result = await ElementPositionDetector.detectElementPosition(
      image, "Telegram icon");
  print(result.toJson());
}
