import 'package:dio/dio.dart';

import '../../../../core/network/api_failure.dart';
import '../../../catalog/data/server_model.dart';
import 'admin_server_contracts.dart';

class AdminServerRepository {
  const AdminServerRepository(this._dio);

  final Dio _dio;

  Future<List<ServerModel>> getServers() async {
    final response = await _dio.get<Object?>('/admin/servers');
    final values = _requiredList(response.data, 'GET /admin/servers response');
    return List<ServerModel>.unmodifiable(
      values.map(
        (value) => ServerModel.fromJson(
          _requiredObject(value, 'GET /admin/servers item'),
        ),
      ),
    );
  }

  Future<ServerModel> getServer(int serverId) async {
    final response = await _dio.get<Object?>('/admin/servers/$serverId');
    return ServerModel.fromJson(
      _requiredObject(response.data, 'GET /admin/servers/{id} response'),
    );
  }

  Future<ServerModel> createServer(AdminServerUpsertRequest request) async {
    final response = await _dio.post<Object?>(
      '/admin/servers',
      data: request.toJson(),
    );
    return ServerModel.fromJson(
      _requiredObject(response.data, 'POST /admin/servers response'),
    );
  }

  Future<ServerModel> updateServer(
    int serverId,
    AdminServerUpsertRequest request,
  ) async {
    try {
      final response = await _dio.put<Object?>(
        '/admin/servers/$serverId',
        data: request.toJson(),
      );
      return ServerModel.fromJson(
        _requiredObject(response.data, 'PUT /admin/servers/{id} response'),
      );
    } on Object catch (error) {
      if (_isAmbiguousMutationFailure(error)) {
        try {
          final authoritative = await getServer(serverId);
          if (request.matches(authoritative)) return authoritative;
        } on Object {
          // Preserve the original mutation error when reconciliation fails.
        }
      }
      rethrow;
    }
  }

  Future<void> softDeleteServer(int serverId) async {
    try {
      await _dio.delete<Object?>('/admin/servers/$serverId');
    } on Object catch (error) {
      if (_isAmbiguousMutationFailure(error)) {
        try {
          final authoritative = await getServer(serverId);
          if (!authoritative.isActive &&
              authoritative.operationalStatus.toLowerCase() == 'disabled') {
            return;
          }
        } on Object {
          // Preserve the original mutation error when reconciliation fails.
        }
      }
      rethrow;
    }
  }

  Future<List<AdminMaintenanceWindow>> getMaintenance(int serverId) async {
    final response = await _dio.get<Object?>(
      '/admin/servers/$serverId/maintenance',
    );
    final values = _requiredList(
      response.data,
      'GET /admin/servers/{id}/maintenance response',
    );
    return List<AdminMaintenanceWindow>.unmodifiable(
      values.map(
        (value) => AdminMaintenanceWindow.fromJson(
          _requiredObject(value, 'maintenance item'),
        ),
      ),
    );
  }

  Future<AdminMaintenanceWindow> createMaintenance(
    int serverId,
    AdminCreateMaintenanceRequest request,
  ) async {
    try {
      final response = await _dio.post<Object?>(
        '/admin/servers/$serverId/maintenance',
        data: request.toJson(),
      );
      return AdminMaintenanceWindow.fromJson(
        _requiredObject(
          response.data,
          'POST /admin/servers/{id}/maintenance response',
        ),
      );
    } on Object catch (error) {
      if (_isAmbiguousMutationFailure(error)) {
        try {
          final authoritative = await getMaintenance(serverId);
          final matches = authoritative.where(request.matches).toList();
          if (matches.length == 1) return matches.single;
        } on Object {
          // Preserve the original mutation error when reconciliation fails.
        }
      }
      rethrow;
    }
  }

  Future<void> removeMaintenance(int serverId, String windowId) async {
    try {
      await _dio.delete<Object?>('/admin/servers/maintenance/$windowId');
    } on Object catch (error) {
      if (_isAmbiguousMutationFailure(error)) {
        try {
          final authoritative = await getMaintenance(serverId);
          if (authoritative.every((window) => window.id != windowId)) return;
        } on Object {
          // Preserve the original mutation error when reconciliation fails.
        }
      }
      rethrow;
    }
  }
}

bool _isAmbiguousMutationFailure(Object error) {
  final failure = ApiFailure.from(error);
  return failure.kind == ApiFailureKind.offline ||
      failure.kind == ApiFailureKind.timeout ||
      failure.kind == ApiFailureKind.server;
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
