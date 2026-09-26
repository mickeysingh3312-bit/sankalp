import 'package:flutter/material.dart';

import 'app_controller.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    try {
      if (register) {
        await widget.controller.register(name.text, email.text, password.text);
      } else {
        await widget.controller.login(email.text, password.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Sankalp account')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.signedIn) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.account_circle, size: 72),
                const SizedBox(height: 12),
                Text(
                  controller.userName ?? 'Sankalp user',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(controller.userEmail ?? '', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () async {
                          try {
                            await controller.sync();
                          } catch (_) {}
                        },
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync progress now'),
                ),
                TextButton(
                  onPressed: () async {
                    await controller.logout();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Sign out'),
                ),
                if (controller.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      controller.message!,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.self_improvement, size: 64),
              const SizedBox(height: 12),
              Text(
                register ? 'Create your account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your counter works offline. Sign in to sync progress and activate Premium.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (register)
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
              if (register) const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: controller.busy ? null : submit,
                child: Text(register ? 'Create account' : 'Sign in'),
              ),
              TextButton(
                onPressed: controller.busy
                    ? null
                    : () => setState(() => register = !register),
                child: Text(register
                    ? 'Already have an account? Sign in'
                    : 'New here? Create an account'),
              ),
              if (!controller.api.configured)
                const Text(
                  'The app build needs its API_BASE_URL before account access can connect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange),
                ),
              if (controller.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    controller.message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

