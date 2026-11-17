import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    this.environment = const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    this.apiBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '/api/v1'),
    this.publicWebUrl = const String.fromEnvironment('PORTAL_WEB_URL'),
    this.version = const String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0'),
  });
  final String environment;
  final String apiBaseUrl;
  final String publicWebUrl;
  final String version;
  String get versionLabel => 'v$version${environment == 'prod' ? '' : ' · $environment'}';
  Uri endpoint(String path, [Map<String, String>? query]) {
    if (!path.startsWith('/') || path.startsWith('//') || path.contains('://')) {
      throw ArgumentError.value(path, 'path', 'Expected relative API path');
    }
    final base = Uri.parse(apiBaseUrl.replaceFirst(RegExp(r'/$'), ''));
    if (!base.hasScheme && !kIsWeb) {
      throw StateError('Set API_BASE_URL to the gateway URL for native builds.');
    }
    final uri = Uri.parse('${base.toString()}$path');
    return (uri.hasScheme ? uri : Uri.base.resolveUri(uri)).replace(queryParameters: query);
  }
}
