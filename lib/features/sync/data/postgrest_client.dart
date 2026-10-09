import 'package:dio/dio.dart';

/// A failed call to the server. [offline] means the phone could not reach it
/// at all, so the sync should simply wait; otherwise [status] is the HTTP
/// status the server answered with.
class RemoteFailure implements Exception {
  RemoteFailure(this.message, {this.offline = false, this.status});

  final String message;
  final bool offline;
  final int? status;

  bool get unauthorized => status == 401 || status == 403;

  @override
  String toString() => 'RemoteFailure($status, offline: $offline): $message';
}

/// The few Supabase REST (PostgREST) calls the sync needs, over Dio.
class PostgrestClient {
  PostgrestClient({
    required Dio dio,
    required String baseUrl,
    required String anonKey,
    required String? Function() accessToken,
  }) : _dio = dio,
       _anonKey = anonKey,
       _token = accessToken {
    _dio.options.baseUrl = '$baseUrl/rest/v1';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  final Dio _dio;
  final String _anonKey;
  final String? Function() _token;

  Options _options({Map<String, String>? extra}) {
    final token = _token();
    return Options(
      headers: {
        'apikey': _anonKey,
        // The signed-in user's token; the project key alone is not a token.
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?extra,
      },
    );
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw RemoteFailure(
        e.response?.data?.toString() ?? e.message ?? 'request failed',
        offline: status == null,
        status: status,
      );
    }
  }

  /// Inserts or updates rows by id. The server ignores a row older than the
  /// one it already has.
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return Future.value();
    return _guard(
      () => _dio.post<void>(
        '/$table',
        queryParameters: {'on_conflict': 'id'},
        data: rows,
        options: _options(
          extra: {'Prefer': 'resolution=merge-duplicates,return=minimal'},
        ),
      ),
    );
  }

  /// Rows changed after the cursor `(ts, id)`, oldest first. Paging by the
  /// pair, not by the time alone, so rows written in the same instant are
  /// never skipped.
  Future<List<Map<String, dynamic>>> changes(
    String table, {
    String? cursorTs,
    String? cursorId,
    int limit = 500,
  }) {
    return _guard(() async {
      final query = <String, dynamic>{
        'select': '*',
        'order': 'server_updated_at.asc,id.asc',
        'limit': limit,
      };
      if (cursorTs != null && cursorId != null) {
        query['or'] =
            '(server_updated_at.gt.$cursorTs,'
            'and(server_updated_at.eq.$cursorTs,id.gt.$cursorId))';
      }
      final res = await _dio.get<List<dynamic>>(
        '/$table',
        queryParameters: query,
        options: _options(),
      );
      return [for (final r in res.data ?? const []) r as Map<String, dynamic>];
    });
  }

  /// Calls a database function with no arguments.
  Future<void> rpc(String name) => _guard(
    () => _dio.post<void>(
      '/rpc/$name',
      data: <String, dynamic>{},
      options: _options(),
    ),
  );
}
