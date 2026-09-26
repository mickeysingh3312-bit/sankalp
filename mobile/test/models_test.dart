import 'package:flutter_test/flutter_test.dart';
import 'package:sankalp_app/src/models.dart';

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
}

