import '../../reservations/data/reservation_models.dart';

class DashboardSummaryModel {
  const DashboardSummaryModel({
    required this.serverTimeUtc,
    required this.primaryState,
    required this.primaryReservation,
    required this.metrics,
  });

  factory DashboardSummaryModel.fromJson(Map<String, Object?> json) {
    return DashboardSummaryModel(
      serverTimeUtc: DateTime.parse(json['serverTimeUtc']! as String).toUtc(),
      primaryState: json['primaryState']! as String,
      primaryReservation: json['primaryReservation'] == null
          ? null
          : DashboardReservationModel.fromJson(
              _object(json['primaryReservation']),
            ),
      metrics: DashboardMetricsModel.fromJson(_object(json['metrics'])),
    );
  }

  final DateTime serverTimeUtc;
  final String primaryState;
  final DashboardReservationModel? primaryReservation;
  final DashboardMetricsModel metrics;
}

class DashboardReservationModel extends MyReservationModel {
  const DashboardReservationModel({
    required super.reservationId,
    required super.startTime,
    required super.endTime,
    required super.totalPrice,
    required super.status,
    required super.paymentStatus,
    required super.server,
    required this.canReserveAgain,
  });

  factory DashboardReservationModel.fromJson(Map<String, Object?> json) {
    final base = MyReservationModel.fromJson(json);
    return DashboardReservationModel(
      reservationId: base.reservationId,
      startTime: base.startTime,
      endTime: base.endTime,
      totalPrice: base.totalPrice,
      status: base.status,
      paymentStatus: base.paymentStatus,
      server: base.server,
      canReserveAgain: json['canReserveAgain']! as bool,
    );
  }

  final bool canReserveAgain;
}

class DashboardMetricsModel {
  const DashboardMetricsModel({
    required this.totalReservations,
    required this.pendingPayment,
    required this.active,
    required this.upcoming,
    required this.completed,
  });
  factory DashboardMetricsModel.fromJson(Map<String, Object?> json) =>
      DashboardMetricsModel(
        totalReservations: (json['totalReservations']! as num).toInt(),
        pendingPayment: (json['pendingPayment']! as num).toInt(),
        active: (json['active']! as num).toInt(),
        upcoming: (json['upcoming']! as num).toInt(),
        completed: (json['completed']! as num).toInt(),
      );
  final int totalReservations;
  final int pendingPayment;
  final int active;
  final int upcoming;
  final int completed;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map) throw const FormatException('Expected a JSON object.');
  return value.map((key, item) => MapEntry(key.toString(), item));
}
