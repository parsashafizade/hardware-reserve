import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/features/account/data/profile_model.dart';
import 'package:hardware_reserve/features/reservations/data/reservation_models.dart';

void main() {
  test('reservation writes always use canonical UTC timestamps', () {
    final request = CreateReservationRequestModel(
      serverId: 7,
      startTime: DateTime.parse('2026-08-20T12:00:00+03:30'),
      endTime: DateTime.parse('2026-08-20T16:30:00+03:30'),
      quotedTotalPrice: 250000,
    ).toJson();

    expect(request['startTime'], '2026-08-20T08:30:00.000Z');
    expect(request['endTime'], '2026-08-20T13:00:00.000Z');
    expect(request['quotedTotalPrice'], 250000);
  });

  test(
    'status and money values remain backend-authoritative strings/numbers',
    () {
      final reservation = MyReservationModel.fromJson({
        'reservationId': 12,
        'startTime': '2026-08-20T08:30:00Z',
        'endTime': '2026-08-20T13:00:00Z',
        'totalPrice': 120000.5,
        'status': 'PendingPayment',
        'paymentStatus': 'Unpaid',
        'server': {
          'serverId': 7,
          'cpu': 'AMD EPYC',
          'gpu': 'RTX 4090',
          'ram': '128 GB',
          'storage': '2 TB NVMe',
          'os': 'Ubuntu',
        },
      });

      expect(reservation.status, 'PendingPayment');
      expect(reservation.paymentStatus, 'Unpaid');
      expect(reservation.totalPrice, 120000.5);
      expect(reservation.startTime.isUtc, isTrue);
    },
  );

  test('relative profile images resolve against the one API origin', () {
    expect(
      resolveProfileImageUrl(
        '/uploads/profile.webp',
        apiBaseUrl: 'https://api.example.com',
      ),
      'https://api.example.com/uploads/profile.webp',
    );
  });
}
