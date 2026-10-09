/// Translates a row between the phone's shape (camelCase, as written by
/// Drift's `toJson`) and the server's shape (snake_case, ISO dates).
///
/// Pure functions, so the rules are easy to test.
class RowCodec {
  RowCodec._();

  /// Columns that hold a calendar day, not a moment in time.
  static const _dayKeys = {
    'occurredOn',
    'activeFrom',
    'targetDate',
    'startOn',
    'nextRunOn',
    'startedOn',
    'dueOn',
  };

  /// Columns that hold a moment in time.
  static const _momentKeys = {'updatedAt', 'deletedAt'};

  /// Only the phone knows these.
  static const _localOnly = {'syncState'};

  static String snake(String key) => key.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );

  static String camel(String key) => key.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (m) => m.group(1)!.toUpperCase(),
  );

  static String _day(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }

  /// A local row as the server wants it. [userId] becomes the owner.
  static Map<String, dynamic> toRemote(
    Map<String, dynamic> local,
    String userId,
  ) {
    final out = <String, dynamic>{};
    local.forEach((key, value) {
      if (_localOnly.contains(key)) return;
      var v = value;
      if (v is int && _dayKeys.contains(key)) {
        v = _day(v);
      } else if (v is int && _momentKeys.contains(key)) {
        v = DateTime.fromMillisecondsSinceEpoch(
          v,
          isUtc: true,
        ).toIso8601String();
      } else if (key == 'receiptPath') {
        // A file path on this phone means nothing anywhere else.
        v = null;
      }
      out[snake(key)] = v;
    });
    out['owner_id'] = userId;
    return out;
  }

  /// A server row as Drift's `fromJson` reads it. The row counts as synced.
  static Map<String, dynamic> fromRemote(Map<String, dynamic> remote) {
    final out = <String, dynamic>{};
    remote.forEach((key, value) {
      if (key == 'server_updated_at') return;
      final k = camel(key);
      var v = value;
      if (v is String && _dayKeys.contains(k)) {
        final parts = v.split('-');
        v = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ).millisecondsSinceEpoch;
      } else if (v is String && _momentKeys.contains(k)) {
        v = DateTime.parse(v).millisecondsSinceEpoch;
      }
      out[k] = v;
    });
    out['syncState'] = 'synced';
    return out;
  }
}
