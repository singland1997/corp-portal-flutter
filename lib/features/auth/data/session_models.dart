import 'package:flutter/widgets.dart';
import '../../../core/api/api_failure.dart';

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw const ApiFailure(code: 'INVALID_RESPONSE', message: 'Invalid session response.');
  return value;
}

class CorporateAccount {
  const CorporateAccount({required this.id, required this.name, this.nameTh, this.code, this.lotId});
  final String id, name;
  final String? nameTh, code, lotId;
  String displayName(Locale locale) => locale.languageCode == 'th' ? nameTh ?? name : name;
  factory CorporateAccount.fromJson(Map<String, dynamic> json) => CorporateAccount(
    id: _text(json, 'id'), name: _text(json, 'name'), nameTh: json['nameTh'] as String?,
    code: json['code'] as String?, lotId: json['lotId'] as String?,
  );
}

class SessionUser {
  const SessionUser({required this.id, required this.name, required this.email, required this.role, required this.corporates});
  final String id, name, email, role;
  final List<CorporateAccount> corporates;
  bool get isAdmin => role == 'admin';
  String get initials => name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2).map((s) => s.characters.first).join().toUpperCase();
  factory SessionUser.fromJson(Map<String, dynamic> json) {
    final role = _text(json, 'role');
    if (!{'admin', 'sales', 'corporate'}.contains(role) || json['corporates'] is! List) {
      throw const ApiFailure(code: 'INVALID_RESPONSE', message: 'Invalid session response.');
    }
    final corporates = (json['corporates'] as List).map((c) => CorporateAccount.fromJson(Map<String, dynamic>.from(c as Map))).toList(growable: false);
    if (role == 'corporate' && corporates.length != 1) {
      throw const ApiFailure(code: 'INVALID_RESPONSE', message: 'Invalid corporate scope.');
    }
    return SessionUser(id: _text(json, 'id'), name: _text(json, 'name'), email: _text(json, 'email'), role: role, corporates: List.unmodifiable(corporates));
  }
}

class Session {
  const Session({required this.accessToken, required this.refreshToken, required this.expiresAt, required this.user});
  final String accessToken, refreshToken;
  final DateTime expiresAt;
  final SessionUser user;
  factory Session.fromJson(dynamic value) {
    try {
      final json = Map<String, dynamic>.from(value as Map);
      final expires = json['expiresIn'];
      if (json['tokenType'] != 'Bearer' || expires is! num || expires <= 0 || expires > 86400 ||
          json['refreshToken'] is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(json['refreshToken'])) {
        throw const FormatException();
      }
      return Session(accessToken: _text(json, 'accessToken'), refreshToken: json['refreshToken'],
        expiresAt: DateTime.now().add(Duration(seconds: expires.toInt())),
        user: SessionUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)));
    } catch (_) {
      throw const ApiFailure(code: 'INVALID_RESPONSE', message: 'Invalid authentication response.');
    }
  }
}
