import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:thavika/features/sync/data/postgrest_client.dart';

/// A tiny in-memory stand-in for the Supabase REST API, with the same rules
/// as supabase/migrations/0001_init.sql: ids are unique, an older update is
/// ignored, and every accepted write gets a new `server_updated_at`.
class FakeServer implements HttpClientAdapter {
  final tables = <String, Map<String, Map<String, dynamic>>>{};
  var _clock = 0;

  bool offline = false;
  int? failStatus;

  /// Tables that answer 400 to an upload.
  final rejected = <String>{};

  int requests = 0;

  Iterable<Map<String, dynamic>> rows(String table) =>
      (tables[table] ?? {}).values;

  PostgrestClient client() => PostgrestClient(
    dio: Dio()..httpClientAdapter = this,
    baseUrl: 'http://fake',
    anonKey: 'anon',
    accessToken: () => 'token',
  );

  String _stamp() {
    _clock++;
    return '2026-01-01T00:00:00.${_clock.toString().padLeft(6, '0')}+00:00';
  }

  ResponseBody _json(Object body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    if (failStatus != null) return _json({'message': 'nope'}, failStatus!);

    final table = options.path.split('/').last;
    final store = tables.putIfAbsent(table, () => {});

    if (options.method == 'POST') {
      if (rejected.contains(table)) {
        return _json({'message': 'check violation'}, 400);
      }
      for (final raw in options.data as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final old = store[row['id']];
        if (old != null) {
          final newer = DateTime.parse(row['updated_at'] as String);
          final older = DateTime.parse(old['updated_at'] as String);
          if (newer.isBefore(older)) continue;
          row['owner_id'] = old['owner_id'];
        }
        row['server_updated_at'] = _stamp();
        store[row['id'] as String] = row;
      }
      return _json(<String>[], 201);
    }

    final q = options.uri.queryParameters;
    var list = store.values.toList()
      ..sort((a, b) {
        final c = (a['server_updated_at'] as String).compareTo(
          b['server_updated_at'] as String,
        );
        return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
      });
    final or = q['or'];
    if (or != null) {
      final m = RegExp(
        r'server_updated_at\.gt\.(.+?),and\(server_updated_at\.eq\.(.+?),id\.gt\.(.+?)\)\)$',
      ).firstMatch(or)!;
      final ts = m.group(1)!;
      final id = m.group(3)!;
      list = list.where((r) {
        final t = r['server_updated_at'] as String;
        return t.compareTo(ts) > 0 ||
            (t == ts && (r['id'] as String).compareTo(id) > 0);
      }).toList();
    }
    final limit = int.tryParse(q['limit'] ?? '') ?? 1000;
    return _json(list.take(limit).toList());
  }

  @override
  void close({bool force = false}) {}
}
