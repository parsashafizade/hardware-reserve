import 'package:dio/dio.dart';

import 'dashboard_models.dart';

class DashboardRepository {
  const DashboardRepository(this._dio);
  final Dio _dio;

  Future<DashboardSummaryModel> getSummary() async {
    final response = await _dio.get<Object?>('/dashboard');
    final value = response.data;
    if (value is! Map) {
      throw const FormatException('Dashboard response must be an object.');
    }
    return DashboardSummaryModel.fromJson(
      value.map((key, item) => MapEntry(key.toString(), item)),
    );
  }
}
