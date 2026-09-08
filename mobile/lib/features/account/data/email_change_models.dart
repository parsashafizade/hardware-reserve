import '../../auth/data/auth_models.dart';

class EmailChangeStatusModel {
  const EmailChangeStatusModel({
    required this.currentEmail,
    required this.newEmail,
    required this.currentEmailVerified,
    required this.newEmailVerified,
    required this.currentCodeExpiresAtUtc,
    required this.newCodeExpiresAtUtc,
    required this.currentResendAvailableAtUtc,
    required this.newResendAvailableAtUtc,
    required this.expiresAtUtc,
  });

  factory EmailChangeStatusModel.fromJson(Map<String, dynamic> json) =>
      EmailChangeStatusModel(
        currentEmail: json['currentEmail']! as String,
        newEmail: json['newEmail']! as String,
        currentEmailVerified: json['currentEmailVerified']! as bool,
        newEmailVerified: json['newEmailVerified']! as bool,
        currentCodeExpiresAtUtc: DateTime.parse(
          json['currentCodeExpiresAtUtc']! as String,
        ).toUtc(),
        newCodeExpiresAtUtc: DateTime.parse(
          json['newCodeExpiresAtUtc']! as String,
        ).toUtc(),
        currentResendAvailableAtUtc: DateTime.parse(
          json['currentResendAvailableAtUtc']! as String,
        ).toUtc(),
        newResendAvailableAtUtc: DateTime.parse(
          json['newResendAvailableAtUtc']! as String,
        ).toUtc(),
        expiresAtUtc: DateTime.parse(json['expiresAtUtc']! as String).toUtc(),
      );

  final String currentEmail;
  final String newEmail;
  final bool currentEmailVerified;
  final bool newEmailVerified;
  final DateTime currentCodeExpiresAtUtc;
  final DateTime newCodeExpiresAtUtc;
  final DateTime currentResendAvailableAtUtc;
  final DateTime newResendAvailableAtUtc;
  final DateTime expiresAtUtc;
}

class EmailChangeVerificationModel {
  const EmailChangeVerificationModel({
    required this.completed,
    this.status,
    this.authentication,
  });

  factory EmailChangeVerificationModel.fromJson(Map<String, dynamic> json) =>
      EmailChangeVerificationModel(
        completed: json['completed']! as bool,
        status: json['status'] == null
            ? null
            : EmailChangeStatusModel.fromJson(
                requireJsonObject(json['status']),
              ),
        authentication: json['authentication'] == null
            ? null
            : AuthResponse.fromJson(requireJsonObject(json['authentication'])),
      );

  final bool completed;
  final EmailChangeStatusModel? status;
  final AuthResponse? authentication;
}
