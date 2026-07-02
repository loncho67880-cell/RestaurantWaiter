import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantwaiter/core/utils/reservation_datetime.dart';

void main() {
  group('parseApiReservationDate', () {
    test('treats naive API timestamps as UTC', () {
      final local = parseApiReservationDate('2026-07-02T19:30:00');
      final expectedUtc = DateTime.utc(2026, 7, 2, 19, 30);

      expect(local, expectedUtc.toLocal());
    });

    test('parses explicit UTC suffix', () {
      final local = parseApiReservationDate('2026-07-02T19:30:00.000Z');
      final expectedUtc = DateTime.utc(2026, 7, 2, 19, 30);

      expect(local, expectedUtc.toLocal());
    });

    test('parses explicit offset', () {
      final local = parseApiReservationDate('2026-07-02T14:30:00-05:00');
      final expectedUtc = DateTime.utc(2026, 7, 2, 19, 30);

      expect(local, expectedUtc.toLocal());
    });
  });

  group('formatApiReservationDate', () {
    test('serializes local selection as UTC', () {
      final localSelection = DateTime(2026, 7, 2, 14, 30);

      expect(
        formatApiReservationDate(localSelection),
        localSelection.toUtc().toIso8601String(),
      );
    });
  });
}
