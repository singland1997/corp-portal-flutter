import 'dart:convert';
import 'package:corp_portal_ui/app/responsive_typography.dart';
import 'package:corp_portal_ui/core/api/portal_api.dart';
import 'package:corp_portal_ui/core/config/app_config.dart';
import 'package:corp_portal_ui/features/auth/bloc/auth_bloc.dart';
import 'package:corp_portal_ui/features/auth/data/session_repository.dart';
import 'package:corp_portal_ui/features/auth/data/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

class MemoryTokenStore implements TokenStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

const refreshKey = 'corp-portal.flutter.refresh';
final savedToken = 'a' * 64;

String sessionJson() => jsonEncode({
  'accessToken': 'access', 'refreshToken': 'b' * 64, 'tokenType': 'Bearer', 'expiresIn': 900,
  'user': {'id': 'u1', 'name': 'Test User', 'email': 't@example.com', 'role': 'admin', 'corporates': [{'id': 'c1', 'name': 'Acme'}]},
});

/// Refresh answers with [statuses] in order (200 = a valid session).
(SessionRepository, MemoryTokenStore) repositoryWith(List<int> statuses) {
  var call = 0;
  final client = MockClient((request) async {
    final status = statuses[call < statuses.length ? call : statuses.length - 1];
    call++;
    return status == 200
        ? http.Response(sessionJson(), 200)
        : http.Response(jsonEncode({'error': {'code': 'X', 'message': 'x'}}), status);
  });
  final store = MemoryTokenStore()..values[refreshKey] = savedToken;
  final api = PortalApi(const AppConfig(apiBaseUrl: 'http://api.test/api/v1'), client: client);
  return (SessionRepository(api, store), store);
}

void main() {
  group('session refresh', () {
    test('a 503 keeps the saved session and asks to reconnect', () async {
      final (repository, store) = repositoryWith([503, 200]);
      final bloc = AuthBloc(repository)..add(AuthStarted());
      final failed = await bloc.stream.firstWhere((s) => !s.booting);
      expect(failed.recoveryRequired, isTrue);
      expect(failed.authenticated, isFalse);
      expect(store.values[refreshKey], savedToken, reason: 'refresh token must survive a service error');

      bloc.add(SessionRetryRequested());
      final recovered = await bloc.stream.firstWhere((s) => !s.busy && s.authenticated);
      expect(recovered.recoveryRequired, isFalse);
      expect(store.values[refreshKey], 'b' * 64);
      await bloc.close();
    });

    test('a 401 means the token is invalid: the session is cleared', () async {
      final (repository, store) = repositoryWith([401]);
      final bloc = AuthBloc(repository)..add(AuthStarted());
      final state = await bloc.stream.firstWhere((s) => !s.booting);
      expect(state.authenticated, isFalse);
      expect(state.recoveryRequired, isFalse);
      expect(store.values.containsKey(refreshKey), isFalse);
      await bloc.close();
    });
  });

  group('responsive typography', () {
    test('scales up only above 1920 logical px, at most 1.4x', () {
      expect(viewportFontScale(375), 1);
      expect(viewportFontScale(1920), 1);
      expect(viewportFontScale(2880), closeTo(1.2, 1e-9));
      expect(viewportFontScale(3840), closeTo(1.4, 1e-9));
      expect(viewportFontScale(7680), closeTo(1.4, 1e-9));
    });

    test('keeps the user accessibility text size', () {
      const scaler = ViewportTextScaler(TextScaler.linear(1.5), 1.2);
      expect(scaler.scale(10), closeTo(18, 1e-9));
    });
  });
}
