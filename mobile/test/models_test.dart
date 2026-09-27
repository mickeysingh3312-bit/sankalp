import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sankalp_app/main.dart';
import 'package:sankalp_app/src/app_controller.dart';
import 'package:sankalp_app/src/models.dart';
import 'package:sankalp_app/src/notification_service.dart';
import 'package:sankalp_app/src/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('daily record completion follows its saved goal', () {
    final complete = DailyRecord(
      date: '2026-09-26',
      goal: 108,
      total: 108,
      tap: 50,
      mala: 50,
      write: 8,
    );
    final incomplete = DailyRecord(
      date: '2026-09-26',
      goal: 108,
      total: 107,
      tap: 107,
      mala: 0,
      write: 0,
    );
    expect(complete.complete, isTrue);
    expect(incomplete.complete, isFalse);
    expect(complete.toJson()['total'], 108);
  });

  testWidgets('main Naam Jap screen renders', (tester) async {
    final controller = AppController(
      notifications: NotificationService(),
      purchases: PurchaseService(),
    );

    await tester.pumpWidget(SankalpApp(controller: controller));

    expect(find.text('Sankalp'), findsOneWidget);
    expect(find.text("Choose today's Sankalp"), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  test('changing the selected Naam resets current counting', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(
      notifications: NotificationService(),
      purchases: PurchaseService(),
    );
    await controller.initialize();

    controller.increment(JapMode.tap);
    controller.increment(JapMode.mala);
    controller.increment(JapMode.write);
    expect(controller.count, 3);

    controller.selectMantra('om_namah_shivay');

    expect(controller.count, 0);
    expect(controller.tapCount, 0);
    expect(controller.malaCount, 0);
    expect(controller.writeCount, 0);
    controller.dispose();
  });

  test('tap sound choice is validated and stored in memory', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(
      notifications: NotificationService(),
      purchases: PurchaseService(),
    );
    await controller.initialize();

    controller.setTapSoundChoice('temple_bell');
    expect(controller.tapSoundChoice, 'temple_bell');

    controller.setTapSoundChoice('unknown_sound');
    expect(controller.tapSoundChoice, 'temple_bell');
    controller.dispose();
  });
}
