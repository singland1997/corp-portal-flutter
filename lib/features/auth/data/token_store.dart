import 'token_store_native.dart' if (dart.library.js_interop) 'token_store_web.dart' as platform;

abstract interface class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
TokenStore createTokenStore() => platform.createStore();
