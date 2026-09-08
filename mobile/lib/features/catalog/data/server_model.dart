class ServerWorkloadCapabilityModel {
  const ServerWorkloadCapabilityModel({
    required this.workloadType,
    required this.suitabilityLevel,
  });

  factory ServerWorkloadCapabilityModel.fromJson(Map<String, Object?> json) {
    return ServerWorkloadCapabilityModel(
      workloadType: _requiredString(json, 'workloadType'),
      suitabilityLevel: _requiredInt(json, 'suitabilityLevel'),
    );
  }

  final String workloadType;
  final int suitabilityLevel;
}

class ServerModel {
  const ServerModel({
    required this.id,
    required this.cpu,
    required this.gpu,
    required this.ram,
    required this.storage,
    required this.os,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.isActive,
    required this.operationalStatus,
    required this.finderEligible,
    required this.cpuCapabilityLevel,
    required this.gpuCapabilityLevel,
    required this.performanceTier,
    required this.workloadCapabilities,
  });

  factory ServerModel.fromJson(Map<String, Object?> json) {
    final rawCapabilities = json['workloadCapabilities'];
    if (rawCapabilities is! List<Object?>) {
      throw const FormatException(
        'Server.workloadCapabilities must be a JSON array.',
      );
    }

    return ServerModel(
      id: _requiredInt(json, 'id'),
      cpu: _requiredString(json, 'cpu'),
      gpu: _requiredString(json, 'gpu'),
      ram: _requiredString(json, 'ram'),
      storage: _requiredString(json, 'storage'),
      os: _requiredString(json, 'os'),
      pricePerHour: _requiredDouble(json, 'pricePerHour'),
      pricePerDay: _requiredDouble(json, 'pricePerDay'),
      isActive: _requiredBool(json, 'isActive'),
      operationalStatus: _requiredString(json, 'operationalStatus'),
      finderEligible: _requiredBool(json, 'finderEligible'),
      cpuCapabilityLevel: _requiredInt(json, 'cpuCapabilityLevel'),
      gpuCapabilityLevel: _requiredInt(json, 'gpuCapabilityLevel'),
      performanceTier: _requiredString(json, 'performanceTier'),
      workloadCapabilities: List<ServerWorkloadCapabilityModel>.unmodifiable(
        rawCapabilities.map(
          (value) => ServerWorkloadCapabilityModel.fromJson(
            _requiredObject(value, 'Server.workloadCapabilities item'),
          ),
        ),
      ),
    );
  }

  final int id;
  final String cpu;
  final String gpu;
  final String ram;
  final String storage;
  final String os;
  final double pricePerHour;
  final double pricePerDay;
  final bool isActive;

  /// Preserved verbatim from the API.
  ///
  /// Current values are `Available`, `TemporarilyUnavailable`, `Maintenance`,
  /// and `Disabled`.
  final String operationalStatus;
  final bool finderEligible;
  final int cpuCapabilityLevel;
  final int gpuCapabilityLevel;

  /// Preserved verbatim from the API.
  ///
  /// Current values are `Entry`, `Standard`, `High`, and `Extreme`.
  final String performanceTier;
  final List<ServerWorkloadCapabilityModel> workloadCapabilities;
}

class ServerFilters {
  const ServerFilters({this.cpu, this.gpu, this.ram, this.storage, this.os});

  final String? cpu;
  final String? gpu;
  final String? ram;
  final String? storage;
  final String? os;

  Map<String, Object> toQueryParameters() {
    final query = <String, Object>{};
    _addNonBlank(query, 'cpu', cpu);
    _addNonBlank(query, 'gpu', gpu);
    _addNonBlank(query, 'ram', ram);
    _addNonBlank(query, 'storage', storage);
    _addNonBlank(query, 'os', os);
    return query;
  }

  static void _addNonBlank(
    Map<String, Object> query,
    String key,
    String? value,
  ) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      query[key] = normalized;
    }
  }
}

Map<String, Object?> _requiredObject(Object? value, String field) {
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

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('$key must be a string.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$key must be an integer.');
}

double _requiredDouble(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  throw FormatException('$key must be a finite number.');
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('$key must be a boolean.');
  }
  return value;
}
