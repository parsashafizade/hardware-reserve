import 'package:dio/dio.dart';

import 'server_model.dart';

class ServerRepository {
  const ServerRepository(this._dio);

  final Dio _dio;

  Future<List<ServerModel>> getServers({
    ServerFilters filters = const ServerFilters(),
  }) async {
    final response = await _dio.get<Object?>(
      '/servers',
      queryParameters: filters.toQueryParameters(),
    );
    final values = _requiredList(response.data, 'GET /servers response');
    return List<ServerModel>.unmodifiable(
      values.map(
        (value) =>
            ServerModel.fromJson(_requiredObject(value, 'GET /servers item')),
      ),
    );
  }

  Future<ServerModel> getServerById(int id) async {
    final response = await _dio.get<Object?>('/servers/$id');
    return ServerModel.fromJson(
      _requiredObject(response.data, 'GET /servers/{id} response'),
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
