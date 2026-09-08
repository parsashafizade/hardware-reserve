import 'package:dio/dio.dart';

import '../../data/admin_page_model.dart';
import 'admin_operations_models.dart';

class AdminOperationsRepository {
  const AdminOperationsRepository(this._dio);

  final Dio _dio;

  Future<AdminDashboardStatsModel> getDashboardStats() async {
    final response = await _dio.get<Object?>('/dashboard/stats');
    return AdminDashboardStatsModel.fromJson(response.data);
  }

  Future<AdminPageModel<AdminOrderModel>> getReservations({
    String? query,
    AdminReservationFilter status = AdminReservationFilter.all,
    AdminAssignmentFilter assignmentStatus = AdminAssignmentFilter.all,
    int page = 1,
    int pageSize = 20,
  }) async {
    final normalizedQuery = query?.trim();
    final response = await _dio.get<Object?>(
      '/admin/reservations',
      queryParameters: <String, Object>{
        if (normalizedQuery != null && normalizedQuery.isNotEmpty)
          'query': normalizedQuery,
        if (status.wireValue != null) 'status': status.wireValue!,
        'assignmentStatus': assignmentStatus.wireValue,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return AdminPageModel<AdminOrderModel>.fromJson(
      response.data,
      context: 'Admin reservations page',
      parseItem: AdminOrderModel.fromJson,
    );
  }

  Future<AdminOrderModel> getReservation(int reservationId) async {
    _requirePositiveId(reservationId, 'reservationId');
    final response = await _dio.get<Object?>(
      '/admin/reservations/$reservationId',
    );
    return AdminOrderModel.fromJson(response.data);
  }

  Future<AdminOrderModel> cancelReservation(int reservationId) async {
    _requirePositiveId(reservationId, 'reservationId');
    final response = await _dio.post<Object?>(
      '/admin/reservations/$reservationId/cancel',
    );
    return AdminOrderModel.fromJson(response.data);
  }

  Future<AdminOrderModel> assignCredentials(
    AssignCredentialsRequestModel request,
  ) async {
    _requirePositiveId(request.reservationId, 'reservationId');
    final response = await _dio.post<Object?>(
      '/admin/assign-credentials',
      data: request.toJson(),
    );
    return AdminOrderModel.fromJson(response.data);
  }

  Future<AdminPageModel<AdminUserModel>> searchUsers({
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final normalizedQuery = query?.trim();
    final response = await _dio.get<Object?>(
      '/admin/users/search',
      queryParameters: <String, Object>{
        if (normalizedQuery != null && normalizedQuery.isNotEmpty)
          'query': normalizedQuery,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return AdminPageModel<AdminUserModel>.fromJson(
      response.data,
      context: 'Admin users page',
      parseItem: AdminUserModel.fromJson,
    );
  }

  Future<AdminUserModel> createAdmin(CreateAdminRequestModel request) async {
    final response = await _dio.post<Object?>(
      '/admin/users/admins',
      data: request.toJson(),
    );
    return AdminUserModel.fromJson(response.data);
  }

  Future<AdminUserOverviewModel> getUserOverview(int userId) async {
    _requirePositiveId(userId, 'userId');
    final response = await _dio.get<Object?>('/admin/users/$userId/overview');
    return AdminUserOverviewModel.fromJson(response.data);
  }
}

void _requirePositiveId(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'must be greater than zero');
  }
}
