class CreateReservationRequestModel {
  const CreateReservationRequestModel({
    required this.serverId,
    required this.startTime,
    required this.endTime,
    this.quotedTotalPrice,
  });

  final int serverId;
  final DateTime startTime;
  final DateTime endTime;
  final double? quotedTotalPrice;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'serverId': serverId,
      'startTime': formatApiUtcDateTime(startTime),
      'endTime': formatApiUtcDateTime(endTime),
      if (quotedTotalPrice != null) 'quotedTotalPrice': quotedTotalPrice,
    };
  }
}

class ReservationSuggestionRequestModel {
  const ReservationSuggestionRequestModel({
    required this.serverId,
    required this.desiredDurationHours,
  });

  final int serverId;
  final double desiredDurationHours;

  Map<String, Object> toJson() {
    return <String, Object>{
      'serverId': serverId,
      'desiredDurationHours': desiredDurationHours,
    };
  }
}

class CreateReservationResultModel {
  const CreateReservationResultModel({
    required this.reservationId,
    required this.totalPrice,
    required this.durationSummary,
  });

  factory CreateReservationResultModel.fromJson(Map<String, Object?> json) {
    final reader = _JsonReader(json, 'CreateReservationResult');
    return CreateReservationResultModel(
      reservationId: reader.integer('reservationId'),
      totalPrice: reader.number('totalPrice'),
      durationSummary: reader.string('durationSummary'),
    );
  }

  final int reservationId;
  final double totalPrice;

  /// Legacy, English presentation text. Prefer calculating localized duration
  /// from the requested start and end timestamps.
  final String durationSummary;
}

class ReservationQuoteModel {
  const ReservationQuoteModel({
    required this.serverId,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.totalPrice,
    required this.pricingMode,
    required this.isAvailable,
  });

  factory ReservationQuoteModel.fromJson(Map<String, Object?> json) {
    final reader = _JsonReader(json, 'ReservationQuote');
    return ReservationQuoteModel(
      serverId: reader.integer('serverId'),
      startTime: reader.dateTimeUtc('startTime'),
      endTime: reader.dateTimeUtc('endTime'),
      durationHours: reader.number('durationHours'),
      totalPrice: reader.number('totalPrice'),
      pricingMode: reader.string('pricingMode'),
      isAvailable: reader.boolean('isAvailable'),
    );
  }

  final int serverId;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final double totalPrice;

  /// Preserved verbatim. Current values are `Hourly`, `Daily`, and
  /// `DailyAndHourly`.
  final String pricingMode;
  final bool isAvailable;
}

class ReservationSuggestionModel {
  const ReservationSuggestionModel({
    required this.suggestedStart,
    required this.suggestedEnd,
    required this.message,
  });

  factory ReservationSuggestionModel.fromJson(Map<String, Object?> json) {
    final reader = _JsonReader(json, 'ReservationSuggestion');
    return ReservationSuggestionModel(
      suggestedStart: reader.nullableDateTimeUtc('suggestedStart'),
      suggestedEnd: reader.nullableDateTimeUtc('suggestedEnd'),
      message: reader.string('message'),
    );
  }

  final DateTime? suggestedStart;
  final DateTime? suggestedEnd;

  /// Legacy, English presentation text. Determine availability structurally
  /// from [suggestedStart] and [suggestedEnd].
  final String message;

  bool get hasSuggestion => suggestedStart != null && suggestedEnd != null;
}

class ReservationServerSpecsModel {
  const ReservationServerSpecsModel({
    required this.serverId,
    required this.cpu,
    required this.gpu,
    required this.ram,
    required this.storage,
    required this.os,
  });

  factory ReservationServerSpecsModel.fromJson(Map<String, Object?> json) {
    final reader = _JsonReader(json, 'ReservationServerSpecs');
    return ReservationServerSpecsModel(
      serverId: reader.integer('serverId'),
      cpu: reader.string('cpu'),
      gpu: reader.string('gpu'),
      ram: reader.string('ram'),
      storage: reader.string('storage'),
      os: reader.string('os'),
    );
  }

  final int serverId;
  final String cpu;
  final String gpu;
  final String ram;
  final String storage;
  final String os;
}

class MyReservationModel {
  const MyReservationModel({
    required this.reservationId,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    required this.server,
  });

  factory MyReservationModel.fromJson(Map<String, Object?> json) {
    final reader = _JsonReader(json, 'MyReservation');
    return MyReservationModel(
      reservationId: reader.integer('reservationId'),
      startTime: reader.dateTimeUtc('startTime'),
      endTime: reader.dateTimeUtc('endTime'),
      totalPrice: reader.number('totalPrice'),
      status: reader.string('status'),
      paymentStatus: reader.string('paymentStatus'),
      server: ReservationServerSpecsModel.fromJson(reader.object('server')),
    );
  }

  final int reservationId;
  final DateTime startTime;
  final DateTime endTime;
  final double totalPrice;

  /// Preserved verbatim. Current values are `PendingPayment`, `Paid`, and
  /// `Cancelled`.
  final String status;

  /// Preserved verbatim. This may also be the fallback value `Unpaid` when no
  /// payment exists.
  final String paymentStatus;
  final ReservationServerSpecsModel server;
}

typedef ReservationModel = MyReservationModel;

class ReservationBusySlotModel {
  const ReservationBusySlotModel({
    required this.reservationId,
    required this.startTime,
    required this.endTime,
    required this.source,
  });

  factory ReservationBusySlotModel.fromJson(Map<String, Object?> json) {
    final reader = _JsonReader(json, 'ReservationBusySlot');
    return ReservationBusySlotModel(
      reservationId: reader.nullableInteger('reservationId'),
      startTime: reader.dateTimeUtc('startTime'),
      endTime: reader.dateTimeUtc('endTime'),
      source: reader.string('source'),
    );
  }

  final int? reservationId;
  final DateTime startTime;
  final DateTime endTime;

  /// Preserved verbatim. Current values are `Reservation` and `Maintenance`.
  final String source;
}

typedef BusySlotModel = ReservationBusySlotModel;

class MyServiceModel {
  const MyServiceModel({
    required this.reservationId,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.server,
    required this.assignedIp,
    required this.assignedUsername,
    required this.assignedPassword,
    required this.message,
  });

  factory MyServiceModel.fromJson(Map<String, Object?> json) {
    final reader = _JsonReader(json, 'MyService');
    return MyServiceModel(
      reservationId: reader.integer('reservationId'),
      startTime: reader.dateTimeUtc('startTime'),
      endTime: reader.dateTimeUtc('endTime'),
      totalPrice: reader.number('totalPrice'),
      server: ReservationServerSpecsModel.fromJson(reader.object('server')),
      assignedIp: reader.nullableString('assignedIp'),
      assignedUsername: reader.nullableString('assignedUsername'),
      assignedPassword: reader.nullableString('assignedPassword'),
      message: reader.nullableString('message'),
    );
  }

  final int reservationId;
  final DateTime startTime;
  final DateTime endTime;
  final double totalPrice;
  final ReservationServerSpecsModel server;
  final String? assignedIp;
  final String? assignedUsername;

  /// Sensitive. Keep this in transient screen state only and never log it.
  final String? assignedPassword;

  /// Legacy, English presentation text. Use [credentialsReady] for state.
  final String? message;

  bool get credentialsReady =>
      _isNonBlank(assignedIp) &&
      _isNonBlank(assignedUsername) &&
      _isNonBlank(assignedPassword);
}

class ReservationCockpitModel extends MyReservationModel {
  const ReservationCockpitModel({
    required super.reservationId,
    required super.startTime,
    required super.endTime,
    required super.totalPrice,
    required super.status,
    required super.paymentStatus,
    required super.server,
    required this.serverTimeUtc,
    required this.paymentId,
    required this.paymentDate,
    required this.assignedIp,
    required this.assignedUsername,
    required this.assignedPassword,
  });

  factory ReservationCockpitModel.fromJson(Map<String, Object?> json) {
    final reader = _JsonReader(json, 'ReservationCockpit');
    return ReservationCockpitModel(
      reservationId: reader.integer('reservationId'),
      startTime: reader.dateTimeUtc('startTime'),
      endTime: reader.dateTimeUtc('endTime'),
      totalPrice: reader.number('totalPrice'),
      status: reader.string('status'),
      paymentStatus: reader.string('paymentStatus'),
      server: ReservationServerSpecsModel.fromJson(reader.object('server')),
      serverTimeUtc: reader.dateTimeUtc('serverTimeUtc'),
      paymentId: reader.nullableInteger('paymentId'),
      paymentDate: reader.nullableDateTimeUtc('paymentDate'),
      assignedIp: reader.nullableString('assignedIp'),
      assignedUsername: reader.nullableString('assignedUsername'),
      assignedPassword: reader.nullableString('assignedPassword'),
    );
  }

  final DateTime serverTimeUtc;
  final int? paymentId;
  final DateTime? paymentDate;
  final String? assignedIp;
  final String? assignedUsername;

  /// Sensitive. Keep this in transient screen state only and never log it.
  final String? assignedPassword;

  bool get credentialsReady =>
      _isNonBlank(assignedIp) &&
      _isNonBlank(assignedUsername) &&
      _isNonBlank(assignedPassword);
}

class PaymentResultModel {
  const PaymentResultModel({
    required this.paymentId,
    required this.reservationId,
    required this.amount,
    required this.paymentDate,
    required this.status,
  });

  factory PaymentResultModel.fromJson(Map<String, Object?> json) {
    final reader = _JsonReader(json, 'PaymentResult');
    return PaymentResultModel(
      paymentId: reader.integer('paymentId'),
      reservationId: reader.integer('reservationId'),
      amount: reader.number('amount'),
      paymentDate: reader.dateTimeUtc('paymentDate'),
      status: reader.string('status'),
    );
  }

  final int paymentId;
  final int reservationId;
  final double amount;
  final DateTime paymentDate;

  /// Preserved verbatim. Current values are `Pending`, `Completed`, `Failed`,
  /// and `Refunded`.
  final String status;
}

typedef PaymentModel = PaymentResultModel;

String formatApiUtcDateTime(DateTime value) {
  final encoded = value.toUtc().toIso8601String();
  if (!encoded.endsWith('Z')) {
    throw StateError('UTC timestamps must end with Z.');
  }
  return encoded;
}

bool _isNonBlank(String? value) => value != null && value.trim().isNotEmpty;

class _JsonReader {
  const _JsonReader(this._json, this._context);

  final Map<String, Object?> _json;
  final String _context;

  String string(String key) {
    final value = _json[key];
    if (value is! String) {
      throw FormatException('$_context.$key must be a string.');
    }
    return value;
  }

  String? nullableString(String key) {
    final value = _json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('$_context.$key must be a string or null.');
    }
    return value;
  }

  int integer(String key) {
    final value = _json[key];
    final parsed = _integerValue(value);
    if (parsed == null) {
      throw FormatException('$_context.$key must be an integer.');
    }
    return parsed;
  }

  int? nullableInteger(String key) {
    final value = _json[key];
    if (value == null) {
      return null;
    }
    final parsed = _integerValue(value);
    if (parsed == null) {
      throw FormatException('$_context.$key must be an integer or null.');
    }
    return parsed;
  }

  double number(String key) {
    final value = _json[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('$_context.$key must be a finite number.');
    }
    return value.toDouble();
  }

  bool boolean(String key) {
    final value = _json[key];
    if (value is! bool) {
      throw FormatException('$_context.$key must be a boolean.');
    }
    return value;
  }

  Map<String, Object?> object(String key) {
    return _objectValue(_json[key], '$_context.$key');
  }

  DateTime dateTimeUtc(String key) {
    return _dateTimeValue(string(key), '$_context.$key');
  }

  DateTime? nullableDateTimeUtc(String key) {
    final value = nullableString(key);
    return value == null ? null : _dateTimeValue(value, '$_context.$key');
  }

  static int? _integerValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }

  static Map<String, Object?> _objectValue(Object? value, String field) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('$field must be a JSON object.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException('$field contains a non-string key.');
      }
      result[key] = entry.value;
    }
    return result;
  }

  static DateTime _dateTimeValue(String value, String field) {
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw FormatException('$field must be an ISO-8601 timestamp.');
    }
  }
}
