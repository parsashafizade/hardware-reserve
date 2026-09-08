import '../../data/admin_page_model.dart';

String normalizeAdminWireValue(String value) => value
    .replaceAll(' ', '')
    .replaceAll('_', '')
    .replaceAll('-', '')
    .toLowerCase();

enum AdminReservationFilter {
  all(null),
  pendingPayment('PendingPayment'),
  active('Active'),
  upcoming('Upcoming'),
  completed('Completed'),
  cancelled('Cancelled');

  const AdminReservationFilter(this.wireValue);

  final String? wireValue;
}

enum AdminAssignmentFilter {
  all('All'),
  needsAssignment('NeedsAssignment'),
  assigned('Assigned');

  const AdminAssignmentFilter(this.wireValue);

  final String wireValue;
}

enum AdminAssignmentStatus {
  assigned('Assigned'),
  notAssigned('NotAssigned');

  const AdminAssignmentStatus(this.wireValue);

  final String wireValue;

  factory AdminAssignmentStatus.fromWireValue(String value) {
    return values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => throw FormatException(
        'assignmentStatus must be Assigned or NotAssigned.',
      ),
    );
  }
}

class AdminAuditEventModel {
  const AdminAuditEventModel({
    required this.id,
    required this.adminUserId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.createdAt,
  });

  factory AdminAuditEventModel.fromJson(Object? value) {
    final reader = AdminJsonReader.from(value, 'AdminAuditEvent');
    return AdminAuditEventModel(
      id: reader.string('id'),
      adminUserId: reader.integer('adminUserId'),
      action: reader.string('action'),
      entityType: reader.string('entityType'),
      entityId: reader.string('entityId'),
      details: reader.nullableString('details'),
      createdAt: reader.utcDateTime('createdAt'),
    );
  }

  final String id;
  final int adminUserId;
  final String action;
  final String entityType;
  final String entityId;
  final String? details;
  final DateTime createdAt;
}

class AdminDashboardStatsModel {
  const AdminDashboardStatsModel({
    required this.totalUsers,
    required this.totalServers,
    required this.totalPurchases,
    required this.activeReservations,
    required this.upcomingReservations,
    required this.startingSoonReservations,
    required this.endingSoonReservations,
    required this.pendingPayments,
    required this.unavailableServers,
    required this.maintenanceServers,
    required this.waitingSupportConversations,
    required this.pendingAssignmentReservations,
    required this.supportAttentionConversations,
    required this.recentAuditEvents,
  });

  factory AdminDashboardStatsModel.fromJson(Object? value) {
    final reader = AdminJsonReader.from(value, 'DashboardStats');
    return AdminDashboardStatsModel(
      totalUsers: reader.integer('totalUsers'),
      totalServers: reader.integer('totalServers'),
      totalPurchases: reader.integer('totalPurchases'),
      activeReservations: reader.integer('activeReservations'),
      upcomingReservations: reader.integer('upcomingReservations'),
      startingSoonReservations: reader.integer('startingSoonReservations'),
      endingSoonReservations: reader.integer('endingSoonReservations'),
      pendingPayments: reader.integer('pendingPayments'),
      unavailableServers: reader.integer('unavailableServers'),
      maintenanceServers: reader.integer('maintenanceServers'),
      waitingSupportConversations: reader.integer(
        'waitingSupportConversations',
      ),
      pendingAssignmentReservations: reader.integer(
        'pendingAssignmentReservations',
      ),
      supportAttentionConversations: reader.integer(
        'supportAttentionConversations',
      ),
      recentAuditEvents: List<AdminAuditEventModel>.unmodifiable(
        reader.list('recentAuditEvents').map(AdminAuditEventModel.fromJson),
      ),
    );
  }

  final int totalUsers;
  final int totalServers;
  final int totalPurchases;
  final int activeReservations;
  final int upcomingReservations;
  final int startingSoonReservations;
  final int endingSoonReservations;
  final int pendingPayments;
  final int unavailableServers;
  final int maintenanceServers;
  final int waitingSupportConversations;
  final int pendingAssignmentReservations;
  final int supportAttentionConversations;
  final List<AdminAuditEventModel> recentAuditEvents;
}

class AdminOrderModel {
  const AdminOrderModel({
    required this.reservationId,
    required this.userId,
    required this.userFullName,
    required this.userEmail,
    required this.serverId,
    required this.cpu,
    required this.gpu,
    required this.ram,
    required this.storage,
    required this.os,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.reservationStatus,
    required this.paymentStatus,
    required this.credentialsAssigned,
    required this.assignmentStatus,
    required this.assignedIp,
    required this.assignedUsername,
    required this.assignedPassword,
  });

  factory AdminOrderModel.fromJson(Object? value) {
    final reader = AdminJsonReader.from(value, 'AdminOrder');
    final credentialsAssigned = reader.boolean('credentialsAssigned');
    final assignmentStatus = AdminAssignmentStatus.fromWireValue(
      reader.string('assignmentStatus'),
    );
    if (credentialsAssigned !=
        (assignmentStatus == AdminAssignmentStatus.assigned)) {
      throw const FormatException(
        'credentialsAssigned and assignmentStatus must agree.',
      );
    }
    return AdminOrderModel(
      reservationId: reader.integer('reservationId'),
      userId: reader.integer('userId'),
      userFullName: reader.string('userFullName'),
      userEmail: reader.string('userEmail'),
      serverId: reader.integer('serverId'),
      cpu: reader.string('cpu'),
      gpu: reader.string('gpu'),
      ram: reader.string('ram'),
      storage: reader.string('storage'),
      os: reader.string('os'),
      startTime: reader.utcDateTime('startTime'),
      endTime: reader.utcDateTime('endTime'),
      totalPrice: reader.number('totalPrice'),
      reservationStatus: reader.string('reservationStatus'),
      paymentStatus: reader.string('paymentStatus'),
      credentialsAssigned: credentialsAssigned,
      assignmentStatus: assignmentStatus,
      // These fields are present only on the protected Admin detail contract.
      assignedIp: reader.nullableString('assignedIp'),
      assignedUsername: reader.nullableString('assignedUsername'),
      assignedPassword: reader.nullableString('assignedPassword'),
    );
  }

  final int reservationId;
  final int userId;
  final String userFullName;
  final String userEmail;
  final int serverId;
  final String cpu;
  final String gpu;
  final String ram;
  final String storage;
  final String os;
  final DateTime startTime;
  final DateTime endTime;
  final double totalPrice;
  final String reservationStatus;
  final String paymentStatus;

  /// True only when the backend confirms that all three connection fields exist.
  /// List responses omit secrets; the protected detail response populates them.
  final bool credentialsAssigned;
  final AdminAssignmentStatus assignmentStatus;
  final String? assignedIp;
  final String? assignedUsername;
  final String? assignedPassword;

  bool get hasReadableCredentials =>
      (assignedIp?.trim().isNotEmpty ?? false) &&
      (assignedUsername?.trim().isNotEmpty ?? false) &&
      (assignedPassword?.isNotEmpty ?? false);

  String get hardwareLabel =>
      normalizeAdminWireValue(gpu) == 'none' ? cpu : gpu;
  bool get isPaid => normalizeAdminWireValue(reservationStatus) == 'paid';
  bool get isCancelled =>
      normalizeAdminWireValue(reservationStatus) == 'cancelled';
  bool canCancelAt([DateTime? now]) =>
      !isCancelled && endTime.isAfter((now ?? DateTime.now()).toUtc());

  AdminOrderModel copyWith({
    String? reservationStatus,
    String? paymentStatus,
    bool? credentialsAssigned,
    AdminAssignmentStatus? assignmentStatus,
    Object? assignedIp = _adminUnset,
    Object? assignedUsername = _adminUnset,
    Object? assignedPassword = _adminUnset,
  }) {
    return AdminOrderModel(
      reservationId: reservationId,
      userId: userId,
      userFullName: userFullName,
      userEmail: userEmail,
      serverId: serverId,
      cpu: cpu,
      gpu: gpu,
      ram: ram,
      storage: storage,
      os: os,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
      reservationStatus: reservationStatus ?? this.reservationStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      credentialsAssigned: credentialsAssigned ?? this.credentialsAssigned,
      assignmentStatus: assignmentStatus ?? this.assignmentStatus,
      assignedIp: identical(assignedIp, _adminUnset)
          ? this.assignedIp
          : assignedIp as String?,
      assignedUsername: identical(assignedUsername, _adminUnset)
          ? this.assignedUsername
          : assignedUsername as String?,
      assignedPassword: identical(assignedPassword, _adminUnset)
          ? this.assignedPassword
          : assignedPassword as String?,
    );
  }
}

const Object _adminUnset = Object();

class AdminUserModel {
  const AdminUserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.isEmailVerified,
  });

  factory AdminUserModel.fromJson(Object? value) {
    final reader = AdminJsonReader.from(value, 'AdminUser');
    return AdminUserModel(
      id: reader.integer('id'),
      fullName: reader.string('fullName'),
      email: reader.string('email'),
      role: reader.string('role'),
      createdAt: reader.utcDateTime('createdAt'),
      isEmailVerified: reader.boolean('isEmailVerified'),
    );
  }

  final int id;
  final String fullName;
  final String email;
  final String role;
  final DateTime createdAt;
  final bool isEmailVerified;

  bool get isAdmin => normalizeAdminWireValue(role) == 'admin';
}

class CreateAdminRequestModel {
  const CreateAdminRequestModel({
    required this.fullName,
    required this.email,
    required this.password,
  });

  final String fullName;
  final String email;
  final String password;

  Map<String, Object> toJson() => <String, Object>{
    'fullName': fullName.trim(),
    'email': email.trim(),
    'password': password,
  };
}

class AdminUserOverviewModel {
  const AdminUserOverviewModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isEmailVerified,
    required this.emailVerifiedAt,
    required this.createdAt,
    required this.reservationCount,
    required this.activeReservationCount,
    required this.completedPaymentCount,
    required this.supportConversationCount,
    required this.unreadNotificationCount,
    required this.recentReservations,
  });

  factory AdminUserOverviewModel.fromJson(Object? value) {
    final reader = AdminJsonReader.from(value, 'AdminUserOverview');
    return AdminUserOverviewModel(
      id: reader.integer('id'),
      fullName: reader.string('fullName'),
      email: reader.string('email'),
      role: reader.string('role'),
      isEmailVerified: reader.boolean('isEmailVerified'),
      emailVerifiedAt: reader.nullableUtcDateTime('emailVerifiedAt'),
      createdAt: reader.utcDateTime('createdAt'),
      reservationCount: reader.integer('reservationCount'),
      activeReservationCount: reader.integer('activeReservationCount'),
      completedPaymentCount: reader.integer('completedPaymentCount'),
      supportConversationCount: reader.integer('supportConversationCount'),
      unreadNotificationCount: reader.integer('unreadNotificationCount'),
      recentReservations: List<AdminOrderModel>.unmodifiable(
        reader.list('recentReservations').map(AdminOrderModel.fromJson),
      ),
    );
  }

  final int id;
  final String fullName;
  final String email;
  final String role;
  final bool isEmailVerified;
  final DateTime? emailVerifiedAt;
  final DateTime createdAt;
  final int reservationCount;
  final int activeReservationCount;
  final int completedPaymentCount;
  final int supportConversationCount;
  final int unreadNotificationCount;
  final List<AdminOrderModel> recentReservations;

  bool get isAdmin => normalizeAdminWireValue(role) == 'admin';
}

class AssignCredentialsRequestModel {
  const AssignCredentialsRequestModel({
    required this.reservationId,
    required this.assignedIp,
    required this.assignedUsername,
    required this.assignedPassword,
  });

  final int reservationId;
  final String assignedIp;
  final String assignedUsername;
  final String assignedPassword;

  Map<String, Object> toJson() => <String, Object>{
    'reservationId': reservationId,
    'assignedIp': assignedIp.trim(),
    'assignedUsername': assignedUsername.trim(),
    // Do not log, cache, or otherwise persist this map.
    'assignedPassword': assignedPassword,
  };
}
