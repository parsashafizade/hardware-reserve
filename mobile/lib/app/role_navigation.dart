import '../features/auth/data/auth_models.dart';

bool _isSafeInternalPath(String? path) =>
    path != null && path.startsWith('/') && !path.startsWith('//');

bool _isAdminPath(String path) =>
    path == '/admin' || path.startsWith('/admin/') || path.startsWith('/admin?');

String authenticatedLandingPath(
  AuthenticatedUser user, {
  String? requestedPath,
}) {
  if (user.isAdmin) {
    return _isSafeInternalPath(requestedPath) && _isAdminPath(requestedPath!)
        ? requestedPath
        : '/admin';
  }

  return _isSafeInternalPath(requestedPath) && !_isAdminPath(requestedPath!)
      ? requestedPath
      : '/';
}
