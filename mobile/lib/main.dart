import 'package:flutter/material.dart';

import 'src/app_controller.dart';
import 'src/home_screen.dart';
import 'src/notification_service.dart';
import 'src/purchase_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = NotificationService();
  final controller = AppController(
    notifications: notifications,
    purchases: PurchaseService(),
  );
  runApp(SankalpBootstrap(
    controller: controller,
    notifications: notifications,
  ));
}

class SankalpBootstrap extends StatefulWidget {
  const SankalpBootstrap({
    super.key,
    required this.controller,
    required this.notifications,
  });

  final AppController controller;
  final NotificationService notifications;

  @override
  State<SankalpBootstrap> createState() => _SankalpBootstrapState();
}

class _SankalpBootstrapState extends State<SankalpBootstrap> {
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!_loading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await widget.notifications.initialize();
      await widget.controller.initialize();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null) {
      return SankalpApp(controller: widget.controller);
    }

    const saffron = Color(0xFFFF7A21);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: saffron,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1C140C),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _error == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('ॐ', style: TextStyle(fontSize: 54, color: saffron)),
                        SizedBox(height: 18),
                        CircularProgressIndicator(color: saffron),
                        SizedBox(height: 18),
                        Text('Preparing Naam Jap…'),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('ॐ', style: TextStyle(fontSize: 54, color: saffron)),
                        const SizedBox(height: 18),
                        const Text(
                          'Naam Jap could not finish starting.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _initialize,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
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
          title: 'Naam Jap',
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
