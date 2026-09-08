import 'package:dio/dio.dart';

import 'profile_model.dart';

class ProfileRepository {
  const ProfileRepository(this._dio);

  final Dio _dio;

  Future<ProfileModel> getProfile() async {
    final response = await _dio.get<Object?>('/me');
    return _parseProfile(response.data, 'GET /me response');
  }

  Future<ProfileModel> updateProfile(String fullName) async {
    final response = await _dio.put<Object?>(
      '/me',
      data: <String, Object>{'fullName': fullName.trim()},
    );
    return _parseProfile(response.data, 'PUT /me response');
  }

  /// Uploads an image selected through a mobile file API such as image_picker.
  ///
  /// The backend requires the multipart field name `file`, a filename ending in
  /// `.jpg`, `.jpeg`, `.png`, or `.webp`, and a file smaller than 2 MiB. Keep
  /// client output below the hard limit to leave room for multipart overhead.
  Future<ProfileModel> uploadProfileImage(
    String filePath, {
    String? fileName,
  }) async {
    final uploadName = fileName?.trim().isNotEmpty == true
        ? fileName!.trim()
        : _fileNameFromPath(filePath);
    final file = await MultipartFile.fromFile(filePath, filename: uploadName);
    return _uploadProfileImage(file);
  }

  /// Byte-based alternative for cropped or otherwise in-memory mobile images.
  Future<ProfileModel> uploadProfileImageBytes(
    List<int> bytes, {
    required String fileName,
  }) {
    final file = MultipartFile.fromBytes(bytes, filename: fileName.trim());
    return _uploadProfileImage(file);
  }

  Future<ProfileModel> _uploadProfileImage(MultipartFile file) async {
    final formData = FormData.fromMap(<String, Object>{'file': file});
    final response = await _dio.post<Object?>(
      '/me/profile-image',
      data: formData,
    );
    return _parseProfile(response.data, 'POST /me/profile-image response');
  }

  ProfileModel _parseProfile(Object? value, String label) {
    return ProfileModel.fromJson(
      _requiredObject(value, label),
      apiBaseUrl: _dio.options.baseUrl,
    );
  }
}

String _fileNameFromPath(String filePath) {
  final normalized = filePath.replaceAll('\\', '/');
  final name = normalized.split('/').last.trim();
  if (name.isEmpty) {
    throw const FormatException('Profile image path must include a filename.');
  }
  return name;
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
