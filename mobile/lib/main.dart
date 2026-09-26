import 'package:flutter/material.dart';

import 'src/app_controller.dart';
import 'src/home_screen.dart';
import 'src/notification_service.dart';
import 'src/purchase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = NotificationService();
  await notifications.initialize();
  final controller = AppController(
    notifications: notifications,
    purchases: PurchaseService(),
  );
  await controller.initialize();
  runApp(SankalpApp(controller: controller));
}

class SankalpApp extends StatelessWidget {
  const SankalpApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Sankalp',
          debugShowCheckedModeBanner: false,
          themeMode: controller.themeMode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: HomeScreen(controller: controller),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    const saffron = Color(0xFFFF7A21);
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: saffron,
      brightness: brightness,
      surface: dark ? const Color(0xFF2A2016) : Colors.white,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF1C140C) : const Color(0xFFFFF8EE),
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

