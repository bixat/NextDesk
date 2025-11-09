import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bixat_key_mouse/bixat_key_mouse.dart';
import 'config/app_theme.dart';
import 'providers/app_state.dart';
import 'services/config_service.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  // Initialize ConfigService
  final configService = ConfigService();
  await configService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configService),
        ChangeNotifierProvider(create: (_) => AppState(config: configService)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextDesk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}
