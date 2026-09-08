import 'package:dio/dio.dart';

import 'reservation_models.dart';

class ReservationRepository {
  const ReservationRepository(this._dio);

  final Dio _dio;

  Future<ReservationQuoteModel> quoteReservation(
    CreateReservationRequestModel request,
  ) async {
    final response = await _dio.post<Object?>(
      '/reservations/quote',
      data: request.toJson(),
    );
    return ReservationQuoteModel.fromJson(
      _requiredObject(response.data, 'POST /reservations/quote response'),
    );
  }

  Future<ReservationSuggestionModel> suggestReservation(
    ReservationSuggestionRequestModel request,
  ) async {
    final response = await _dio.post<Object?>(
      '/reservations/suggest',
      data: request.toJson(),
    );
    return ReservationSuggestionModel.fromJson(
      _requiredObject(response.data, 'POST /reservations/suggest response'),
    );
  }

  /// Creates a reservation.
  ///
  /// The backend does not currently accept an idempotency key. Do not
  /// automatically retry this call after an ambiguous network failure; first
  /// reconcile with [getMyReservations].
  Future<CreateReservationResultModel> createReservation(
    CreateReservationRequestModel request,
  ) async {
    final response = await _dio.post<Object?>(
      '/reservations',
      data: request.toJson(),
    );
    return CreateReservationResultModel.fromJson(
      _requiredObject(response.data, 'POST /reservations response'),
    );
  }

  Future<List<ReservationBusySlotModel>> getBusySlots(
    int serverId, {
    DateTime? fromUtc,
    DateTime? toUtc,
  }) async {
    final query = <String, Object>{
      if (fromUtc != null) 'fromUtc': formatApiUtcDateTime(fromUtc),
      if (toUtc != null) 'toUtc': formatApiUtcDateTime(toUtc),
    };
    final response = await _dio.get<Object?>(
      '/reservations/server/$serverId/busy',
      queryParameters: query,
    );
    final values = _requiredList(
      response.data,
      'GET /reservations/server/{serverId}/busy response',
    );
    return List<ReservationBusySlotModel>.unmodifiable(
      values.map(
        (value) => ReservationBusySlotModel.fromJson(
          _requiredObject(value, 'Reservation busy-slot item'),
        ),
      ),
    );
  }

  Future<List<MyReservationModel>> getMyReservations() async {
    final response = await _dio.get<Object?>('/my-reservations');
    final values = _requiredList(
      response.data,
      'GET /my-reservations response',
    );
    return List<MyReservationModel>.unmodifiable(
      values.map(
        (value) => MyReservationModel.fromJson(
          _requiredObject(value, 'My-reservations item'),
        ),
      ),
    );
  }

  Future<MyReservationModel> getReservationById(int reservationId) async {
    final response = await _dio.get<Object?>('/reservations/$reservationId');
    return MyReservationModel.fromJson(
      _requiredObject(
        response.data,
        'GET /reservations/{reservationId} response',
      ),
    );
  }

  Future<List<MyServiceModel>> getMyServices() async {
    final response = await _dio.get<Object?>('/my-services');
    final values = _requiredList(response.data, 'GET /my-services response');
    return List<MyServiceModel>.unmodifiable(
      values.map(
        (value) =>
            MyServiceModel.fromJson(_requiredObject(value, 'My-services item')),
      ),
    );
  }

  Future<ReservationCockpitModel> getCockpit(int reservationId) async {
    final response = await _dio.get<Object?>(
      '/reservations/$reservationId/cockpit',
    );
    return ReservationCockpitModel.fromJson(
      _requiredObject(
        response.data,
        'GET /reservations/{reservationId}/cockpit response',
      ),
    );
  }

  /// Pays a reservation using the server-authoritative persisted total.
  ///
  /// The endpoint is not currently idempotent. After an ambiguous network
  /// failure, call [getCockpit] and inspect `paymentStatus`/`paymentId` before
  /// allowing another payment attempt.
  Future<PaymentResultModel> payReservation(int reservationId) async {
    final response = await _dio.post<Object?>('/payments/$reservationId');
    return PaymentResultModel.fromJson(
      _requiredObject(response.data, 'POST /payments/{reservationId} response'),
    );
  }
}

List<Object?> _requiredList(Object? value, String label) {
  if (value is! List<Object?>) {
    throw FormatException('$label must be a JSON array.');
  }
  return value;
}

Map<String, Object?> _requiredObject(Object? value, String label) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$label must be a JSON object.');
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw FormatException('$label contains a non-string key.');
    }
    result[key] = entry.value;
  }
  return result;
}
