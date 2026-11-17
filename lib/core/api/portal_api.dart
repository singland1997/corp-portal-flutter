import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'api_failure.dart';
export 'api_failure.dart';

/// HTTP boundary. Feature repositories own their typed response parsing.
class PortalApi {
  PortalApi(this.config, {http.Client? client, this.timeout = const Duration(seconds: 30)})
      : _client = client ?? http.Client();
  final AppConfig config;
  final http.Client _client;
  final Duration timeout;
  Future<String?> Function()? accessToken;
  Future<String?> Function(String? rejectedToken)? refreshAccessToken;
  Future<void> Function()? sessionExpired;
  final _pendingMutations = <String, String>{};
  String newIdempotencyKey() => const Uuid().v4();
  void clearMutations() => _pendingMutations.clear();

  Future<dynamic> request(String method, String path, {
    Map<String, dynamic>? body, Map<String, String>? query,
    String? corporateId, String? idempotencyKey,
  }) async {
    final isPublic = path.startsWith('/auth/') && path != '/auth/me' && path != '/auth/sessions/current';
    final token = isPublic ? null : await accessToken?.call();
    final mutation = corporateId != null && {'POST', 'PATCH', 'PUT'}.contains(method);
    final fingerprint = '$method|$path|$corporateId|${jsonEncode(body)}';
    final key = idempotencyKey ?? (mutation ? _pendingMutations.putIfAbsent(fingerprint, newIdempotencyKey) : null);
    try {
      try {
        final result = await send(method, path, body: body, query: query, corporateId: corporateId, token: token, idempotencyKey: key);
        _pendingMutations.remove(fingerprint);
        return result;
      } on ApiFailure catch (error) {
        if (isPublic || error.status != 401 || refreshAccessToken == null) rethrow;
        final refreshed = await refreshAccessToken!(token);
        if (refreshed == null) rethrow;
        try {
          final result = await send(method, path, body: body, query: query, corporateId: corporateId, token: refreshed, idempotencyKey: key);
          _pendingMutations.remove(fingerprint);
          return result;
        } on ApiFailure catch (retryError) {
          if (retryError.status == 401) await sessionExpired?.call();
          rethrow;
        }
      }
    } on ApiFailure catch (error) {
      if (error.status != null && error.status! >= 400 && error.status! < 500 && !{408, 429}.contains(error.status)) {
        _pendingMutations.remove(fingerprint);
      }
      rethrow;
    }
  }

  /// Session repository bypasses refresh handling to avoid recursion.
  Future<dynamic> send(String method, String path, {
    Map<String, dynamic>? body, Map<String, String>? query,
    String? corporateId, String? token, String? idempotencyKey,
  }) async {
    try {
      final request = http.Request(method, config.endpoint(path, query));
      request.headers.addAll({
        'Accept': 'application/json', 'Content-Type': 'application/json',
        'X-Request-ID': const Uuid().v4(),
        if (token != null) 'Authorization': 'Bearer $token',
        'X-Corporate-ID': ?corporateId,
        'Idempotency-Key': ?idempotencyKey,
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(await _client.send(request).timeout(timeout)).timeout(timeout);
      dynamic data;
      if (response.bodyBytes.isNotEmpty) {
        try { data = jsonDecode(utf8.decode(response.bodyBytes)); }
        on FormatException {
          throw ApiFailure(code: 'INVALID_RESPONSE', message: 'The service returned an invalid response.', status: response.statusCode);
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = data is Map ? data['error'] : null;
        throw ApiFailure(
          code: error is Map && error['code'] is String ? error['code'] : 'HTTP_ERROR',
          message: error is Map && error['message'] is String ? error['message'] : 'Unable to complete the request.',
          status: response.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiFailure(code: 'TIMEOUT', message: 'The request timed out.');
    } on http.ClientException {
      throw const ApiFailure(code: 'NETWORK_ERROR', message: 'Unable to connect to the service.');
    }
  }
  void close() => _client.close();
}
