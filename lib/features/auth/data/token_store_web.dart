import 'package:web/web.dart' as web;
import 'token_store.dart';

TokenStore createStore() => WebTokenStore();
/// Tab scoped. Not HttpOnly: the existing API uses bearer refresh tokens, not cookies.
class WebTokenStore implements TokenStore {
  @override
  Future<String?> read(String key) async {
    try { return web.window.sessionStorage.getItem(key); } catch (_) { return null; }
  }
  @override
  Future<void> write(String key, String value) async {
    try { web.window.sessionStorage.setItem(key, value); } catch (_) { /* Memory session still works. */ }
  }
  @override
  Future<void> delete(String key) async {
    try { web.window.sessionStorage.removeItem(key); } catch (_) { /* Nothing to restore. */ }
  }
}
