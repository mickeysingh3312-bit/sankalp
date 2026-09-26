import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'app_controller.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final price = controller.purchases.product?.price ?? '₹21/month';
    return Scaffold(
      appBar: AppBar(title: const Text('Sankalp Premium')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('🙏', textAlign: TextAlign.center, style: TextStyle(fontSize: 52)),
            Text(
              controller.isPremium ? 'Premium is active' : 'Turn your Jap into a Sankalp',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 18),
            for (final item in const [
              ('📿', 'Mala mode', 'A complete 108-bead Mala experience'),
              ('✍️', 'Naam writing', 'Write your Naam and count each completion'),
              ('🎯', 'Custom Sankalp', '2,108, custom and 1 lakh monthly targets'),
              ('📊', 'Advanced progress', 'Mode totals, averages and monthly reports'),
              ('🪔', 'Sankalp history', 'Keep completed monthly Sankalps together'),
            ])
              ListTile(
                leading: Text(item.$1, style: const TextStyle(fontSize: 28)),
                title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(item.$3),
              ),
            const SizedBox(height: 16),
            if (controller.isPremium)
              Text(
                'Active until ${controller.premiumUntil!.toLocal().toString().split(' ').first}',
                textAlign: TextAlign.center,
              )
            else ...[
              Text(
                price,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Text(
                'Auto-renews monthly. Cancel anytime in Google Play. Basic Naam Jap remains free.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.busy || !controller.storeReady
                    ? null
                    : () async {
                        if (!controller.signedIn) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountScreen(controller: controller),
                            ),
                          );
                          return;
                        }
                        try {
                          await controller.buyPremium();
                        } catch (_) {}
                      },
                child: Text(controller.signedIn ? 'Start My Sankalp' : 'Sign in to subscribe'),
              ),
              TextButton(
                onPressed: controller.busy ? null : controller.restorePurchases,
                child: const Text('Restore purchase'),
              ),
              if (!controller.storeReady)
                const Text(
                  'Google Play subscription becomes available in an internal-testing or production build.',
                  textAlign: TextAlign.center,
                ),
            ],
            if (controller.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(controller.message!, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}

