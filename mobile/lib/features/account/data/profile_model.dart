class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.profileImagePath,
    required this.profileImageUrl,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(
    Map<String, Object?> json, {
    required String apiBaseUrl,
  }) {
    final id = _requiredInt(json, 'id');
    final fullName = _requiredString(json, 'fullName');
    final email = _requiredString(json, 'email');
    final role = _requiredString(json, 'role');
    final profileImagePath = _nullableString(json, 'profileImagePath');
    final createdAt = _requiredDateTimeUtc(json, 'createdAt');

    return ProfileModel(
      id: id,
      fullName: fullName,
      email: email,
      role: role,
      profileImagePath: profileImagePath,
      profileImageUrl: resolveProfileImageUrl(
        profileImagePath,
        apiBaseUrl: apiBaseUrl,
      ),
      createdAt: createdAt,
    );
  }

  final int id;
  final String fullName;
  final String email;

  /// Preserved verbatim from the server-authoritative role claim.
  final String role;

  /// The raw value returned by the API, normally `/uploads/...`.
  final String? profileImagePath;

  /// [profileImagePath] resolved against the API origin, or an absolute URL
  /// returned by the API unchanged.
  final String? profileImageUrl;
  final DateTime createdAt;
}

String? resolveProfileImageUrl(String? path, {required String apiBaseUrl}) {
  final normalizedPath = path?.trim();
  if (normalizedPath == null || normalizedPath.isEmpty) {
    return null;
  }

  final imageUri = Uri.tryParse(normalizedPath);
  if (imageUri != null && imageUri.hasScheme) {
    return imageUri.toString();
  }

  final baseUri = Uri.tryParse(apiBaseUrl.trim());
  if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
    throw FormatException(
      'Dio baseUrl must be absolute to resolve profileImagePath.',
    );
  }

  return baseUri.resolve(normalizedPath).toString();
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Profile.$key must be a string.');
  }
  return value;
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Profile.$key must be a string or null.');
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
  throw FormatException('Profile.$key must be an integer.');
}

DateTime _requiredDateTimeUtc(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('Profile.$key must be an ISO-8601 timestamp.');
  }
}
