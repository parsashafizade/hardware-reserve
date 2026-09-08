import 'dart:math' as math;

typedef AdminItemParser<T> = T Function(Object? value);

/// Shared offset-page contract used by the backend's Admin endpoints.
class AdminPageModel<T> {
  const AdminPageModel({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory AdminPageModel.fromJson(
    Object? value, {
    required AdminItemParser<T> parseItem,
    String context = 'Admin page',
  }) {
    final reader = AdminJsonReader.from(value, context);
    final rawItems = reader.list('items');
    final page = reader.integer('page');
    final pageSize = reader.integer('pageSize');
    final totalCount = reader.integer('totalCount');

    if (page < 1) {
      throw FormatException('$context.page must be at least 1.');
    }
    if (pageSize < 1 || pageSize > 100) {
      throw FormatException('$context.pageSize must be between 1 and 100.');
    }
    if (totalCount < 0) {
      throw FormatException('$context.totalCount cannot be negative.');
    }

    return AdminPageModel<T>(
      items: List<T>.unmodifiable(rawItems.map(parseItem)),
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;

  int get totalPages => math.max(1, (totalCount / pageSize).ceil());
  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < totalCount;
}

/// Strict JSON reader shared by Admin DTOs. It fails closed when a backend
/// contract changes instead of silently manufacturing operational data.
class AdminJsonReader {
  const AdminJsonReader(this._json, this.context);

  factory AdminJsonReader.from(Object? value, String context) {
    if (value is! Map) {
      throw FormatException('$context must be a JSON object.');
    }

    final object = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('$context contains a non-string key.');
      }
      object[entry.key as String] = entry.value;
    }
    return AdminJsonReader(object, context);
  }

  final Map<String, Object?> _json;
  final String context;

  Object? value(String key) => _json[key];

  String string(String key) {
    final value = _json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$context.$key must be a non-empty string.');
    }
    return value;
  }

  String? nullableString(String key) {
    final value = _json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$context.$key must be a string or null.');
    }
    return value;
  }

  int integer(String key) {
    final value = _json[key];
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncateToDouble()) {
      return value.toInt();
    }
    throw FormatException('$context.$key must be an integer.');
  }

  double number(String key) {
    final value = _json[key];
    if (value is num && value.isFinite) return value.toDouble();
    throw FormatException('$context.$key must be a finite number.');
  }

  bool boolean(String key) {
    final value = _json[key];
    if (value is bool) return value;
    throw FormatException('$context.$key must be a boolean.');
  }

  List<Object?> list(String key) {
    final value = _json[key];
    if (value is List) return List<Object?>.from(value);
    throw FormatException('$context.$key must be a JSON array.');
  }

  DateTime utcDateTime(String key) => _parseUtcDateTime(string(key), key);

  DateTime? nullableUtcDateTime(String key) {
    final value = _json[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        '$context.$key must be an ISO-8601 timestamp or null.',
      );
    }
    return _parseUtcDateTime(value, key);
  }

  DateTime _parseUtcDateTime(String value, String key) {
    final raw = value.trim();
    final separator = math.max(raw.lastIndexOf('T'), raw.lastIndexOf(' '));
    final offset = math.max(raw.lastIndexOf('+'), raw.lastIndexOf('-'));
    final hasZone =
        raw.endsWith('Z') ||
        raw.endsWith('z') ||
        (separator >= 0 && offset > separator);
    final parsed = DateTime.tryParse(hasZone ? raw : '${raw}Z');
    if (parsed == null) {
      throw FormatException('$context.$key must be an ISO-8601 timestamp.');
    }
    return parsed.toUtc();
  }
}
