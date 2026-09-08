import '../../../catalog/data/server_model.dart';

enum AdminServerOperationalStatus {
  available('Available'),
  temporarilyUnavailable('TemporarilyUnavailable'),
  maintenance('Maintenance'),
  disabled('Disabled');

  const AdminServerOperationalStatus(this.wireValue);

  final String wireValue;

  static AdminServerOperationalStatus fromWire(String value) {
    return values.firstWhere(
      (item) => item.wireValue.toLowerCase() == value.toLowerCase(),
      orElse: () =>
          throw FormatException('Unknown server operational status: $value'),
    );
  }
}

enum AdminServerPerformanceTier {
  entry('Entry'),
  standard('Standard'),
  high('High'),
  extreme('Extreme');

  const AdminServerPerformanceTier(this.wireValue);

  final String wireValue;

  static AdminServerPerformanceTier fromWire(String value) {
    return values.firstWhere(
      (item) => item.wireValue.toLowerCase() == value.toLowerCase(),
      orElse: () =>
          throw FormatException('Unknown server performance tier: $value'),
    );
  }
}

enum AdminServerWorkloadType {
  modelTraining('ModelTraining'),
  inference('Inference'),
  rendering('Rendering'),
  developmentCompilation('DevelopmentCompilation'),
  dataProcessing('DataProcessing'),
  webBackendHosting('WebBackendHosting'),
  generalCompute('GeneralCompute');

  const AdminServerWorkloadType(this.wireValue);

  final String wireValue;

  static AdminServerWorkloadType fromWire(String value) {
    return values.firstWhere(
      (item) => item.wireValue.toLowerCase() == value.toLowerCase(),
      orElse: () =>
          throw FormatException('Unknown server workload type: $value'),
    );
  }
}

class AdminServerUpsertRequest {
  const AdminServerUpsertRequest({
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

  factory AdminServerUpsertRequest.fromServer(ServerModel server) {
    return AdminServerUpsertRequest(
      cpu: server.cpu,
      gpu: server.gpu,
      ram: server.ram,
      storage: server.storage,
      os: server.os,
      pricePerHour: server.pricePerHour,
      pricePerDay: server.pricePerDay,
      isActive: server.isActive,
      operationalStatus: AdminServerOperationalStatus.fromWire(
        server.operationalStatus,
      ),
      finderEligible: server.finderEligible,
      cpuCapabilityLevel: server.cpuCapabilityLevel,
      gpuCapabilityLevel: server.gpuCapabilityLevel,
      performanceTier: AdminServerPerformanceTier.fromWire(
        server.performanceTier,
      ),
      workloadCapabilities: Map<AdminServerWorkloadType, int>.unmodifiable({
        for (final capability in server.workloadCapabilities)
          AdminServerWorkloadType.fromWire(capability.workloadType):
              capability.suitabilityLevel,
      }),
    );
  }

  final String cpu;
  final String gpu;
  final String ram;
  final String storage;
  final String os;
  final double pricePerHour;
  final double pricePerDay;
  final bool isActive;
  final AdminServerOperationalStatus operationalStatus;
  final bool finderEligible;
  final int cpuCapabilityLevel;
  final int gpuCapabilityLevel;
  final AdminServerPerformanceTier performanceTier;
  final Map<AdminServerWorkloadType, int> workloadCapabilities;

  Map<String, Object?> toJson() => <String, Object?>{
    'cpu': cpu.trim(),
    'gpu': gpu.trim(),
    'ram': ram.trim(),
    'storage': storage.trim(),
    'os': os.trim(),
    'pricePerHour': pricePerHour,
    'pricePerDay': pricePerDay,
    'isActive': isActive,
    'operationalStatus': operationalStatus.wireValue,
    'finderEligible': finderEligible,
    'cpuCapabilityLevel': cpuCapabilityLevel,
    'gpuCapabilityLevel': gpuCapabilityLevel,
    'performanceTier': performanceTier.wireValue,
    'workloadCapabilities': <Map<String, Object>>[
      for (final entry in workloadCapabilities.entries)
        <String, Object>{
          'workloadType': entry.key.wireValue,
          'suitabilityLevel': entry.value,
        },
    ],
  };

  bool matches(ServerModel server) {
    if (server.cpu != cpu.trim() ||
        server.gpu != gpu.trim() ||
        server.ram != ram.trim() ||
        server.storage != storage.trim() ||
        server.os != os.trim() ||
        server.pricePerHour != pricePerHour ||
        server.pricePerDay != pricePerDay ||
        server.isActive != isActive ||
        server.operationalStatus.toLowerCase() !=
            operationalStatus.wireValue.toLowerCase() ||
        server.finderEligible != finderEligible ||
        server.cpuCapabilityLevel != cpuCapabilityLevel ||
        server.gpuCapabilityLevel != gpuCapabilityLevel ||
        server.performanceTier.toLowerCase() !=
            performanceTier.wireValue.toLowerCase() ||
        server.workloadCapabilities.length != workloadCapabilities.length) {
      return false;
    }

    for (final capability in server.workloadCapabilities) {
      final type = AdminServerWorkloadType.fromWire(capability.workloadType);
      if (workloadCapabilities[type] != capability.suitabilityLevel) {
        return false;
      }
    }
    return true;
  }
}

class AdminMaintenanceWindow {
  const AdminMaintenanceWindow({
    required this.id,
    required this.serverId,
    required this.startTime,
    required this.endTime,
    required this.reason,
    required this.createdAt,
  });

  factory AdminMaintenanceWindow.fromJson(Map<String, Object?> json) {
    return AdminMaintenanceWindow(
      id: _requiredString(json, 'id'),
      serverId: _requiredInt(json, 'serverId'),
      startTime: _requiredUtcDateTime(json, 'startTime'),
      endTime: _requiredUtcDateTime(json, 'endTime'),
      reason: _optionalString(json, 'reason'),
      createdAt: _requiredUtcDateTime(json, 'createdAt'),
    );
  }

  final String id;
  final int serverId;
  final DateTime startTime;
  final DateTime endTime;
  final String? reason;
  final DateTime createdAt;
}

class AdminCreateMaintenanceRequest {
  const AdminCreateMaintenanceRequest({
    required this.startTime,
    required this.endTime,
    this.reason,
  });

  final DateTime startTime;
  final DateTime endTime;
  final String? reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'startTime': startTime.toUtc().toIso8601String(),
    'endTime': endTime.toUtc().toIso8601String(),
    'reason': _normalizedReason(reason),
  };

  bool matches(AdminMaintenanceWindow window) {
    return window.startTime.isAtSameMomentAs(startTime) &&
        window.endTime.isAtSameMomentAs(endTime) &&
        _normalizedReason(window.reason) == _normalizedReason(reason);
  }
}

String? _normalizedReason(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string or null.');
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$key must be an integer.');
}

DateTime _requiredUtcDateTime(Map<String, Object?> json, String key) {
  final raw = _requiredString(json, key);
  final value = DateTime.tryParse(raw);
  if (value == null) {
    throw FormatException('$key must be an ISO-8601 timestamp.');
  }
  return value.toUtc();
}
