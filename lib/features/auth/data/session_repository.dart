import 'dart:async';
import '../../../core/api/portal_api.dart';
import 'session_models.dart';
import 'token_store.dart';

class SessionRepository {
  SessionRepository(this.api, this.storage) {
    api.accessToken = token;
    api.refreshAccessToken = refresh;
    api.sessionExpired = clear;
  }
  static const _refreshKey = 'corp-portal.flutter.refresh';
  static const _corporateKey = 'corp-portal.flutter.corporate';
  final PortalApi api;
  final TokenStore storage;
  final _changes = StreamController<Session?>.broadcast();
  Stream<Session?> get changes => _changes.stream;
  Session? session;
  String? corporateId;
  Future<String?>? _refreshing;
  /// A refresh may have been consumed even when its response was lost. Stop
  /// automatic retries; let the user explicitly retry after the service recovers.
  ApiFailure? refreshFailure;
  int _generation = 0;
  bool _closed = false;

  Future<void> restore() async {
    corporateId = await storage.read(_corporateKey);
    final saved = await storage.read(_refreshKey);
    if (saved == null) return;
    await refresh(null);
  }

  Future<void> login(String email, String password) async {
    final generation = ++_generation;
    final result = Session.fromJson(await api.send('POST', '/auth/sessions', body: {'email': email.trim(), 'password': password}));
    if (generation != _generation) return;
    corporateId = null;
    await _accept(result, generation);
  }

  Future<void> _accept(Session value, int generation) async {
    if (generation != _generation || _closed) return;
    session = value;
    refreshFailure = null;
    if (!value.user.corporates.any((c) => c.id == corporateId)) {
      corporateId = value.user.corporates.firstOrNull?.id;
    }
    await storage.write(_refreshKey, value.refreshToken);
    if (generation != _generation) { await storage.delete(_refreshKey); return; }
    if (corporateId != null) await storage.write(_corporateKey, corporateId!);
    if (!_closed) _changes.add(session);
  }

  Future<String?> token() async {
    final value = session;
    if (value == null) return null;
    if (value.expiresAt.isBefore(DateTime.now().add(const Duration(seconds: 15)))) return refresh(value.accessToken);
    return value.accessToken;
  }

  Future<String?> refresh(String? rejectedToken) async {
    // A late 401 from the old token reuses the already rotated session.
    if (rejectedToken != null && session != null && session!.accessToken != rejectedToken) return session!.accessToken;
    if (refreshFailure case final failure?) throw failure;
    return _refreshing ??= _rotate().whenComplete(() => _refreshing = null);
  }

  Future<void> retryRefresh() async {
    refreshFailure = null;
    await refresh(session?.accessToken);
  }

  Future<String?> _rotate() async {
    final generation = _generation;
    final saved = session?.refreshToken ?? await storage.read(_refreshKey);
    if (saved == null) { await clear(); return null; }
    try {
      final next = Session.fromJson(await api.send('POST', '/auth/sessions/refresh', body: {'refreshToken': saved}));
      if (generation != _generation || _closed) return null;
      await _accept(next, generation);
      return next.accessToken;
    } on ApiFailure catch (error) {
      if (generation == _generation) {
        if (error.status == 401 || error.status == 403) {
          await clear();
        } else {
          refreshFailure = error;
          if (!_closed) _changes.add(session);
        }
      }
      rethrow;
    }
  }

  Future<void> selectCorporate(String id) async {
    if (!(session?.user.corporates.any((c) => c.id == id) ?? false)) return;
    corporateId = id;
    api.clearMutations();
    await storage.write(_corporateKey, id);
    if (!_closed) _changes.add(session);
  }

  Future<void> logout() async {
    final old = session;
    await clear();
    if (old != null) {
      // Clear locally even if revocation cannot reach the network.
      await api.send('DELETE', '/auth/sessions/current', token: old.accessToken);
    }
  }
  Future<void> clear() async {
    _generation++;
    session = null;
    corporateId = null;
    refreshFailure = null;
    api.clearMutations();
    if (!_closed) _changes.add(null);
    await storage.delete(_refreshKey);
    await storage.delete(_corporateKey);
  }
  Future<void> setupPassword(String token, String password) => api.send('POST', '/auth/password/setup', body: {'token': token, 'password': password});
  Future<void> close() async { _closed = true; _generation++; await _changes.close(); }
}
