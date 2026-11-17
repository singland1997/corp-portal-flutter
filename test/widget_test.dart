import 'dart:convert';
import 'package:corp_portal_ui/shared/business/formatters.dart';
import 'package:corp_portal_ui/app/portal_app.dart';
import 'package:corp_portal_ui/app/router.dart';
import 'package:corp_portal_ui/app/theme.dart';
import 'package:material_ui/material_ui.dart' show Theme, Brightness;
import 'package:corp_portal_ui/core/api/portal_api.dart';
import 'package:corp_portal_ui/core/config/app_config.dart';
import 'package:corp_portal_ui/features/auth/bloc/auth_bloc.dart';
import 'package:corp_portal_ui/features/auth/bloc/set_password_cubit.dart';
import 'package:corp_portal_ui/features/auth/data/session_models.dart';
import 'package:corp_portal_ui/features/auth/data/session_repository.dart';
import 'package:corp_portal_ui/features/auth/data/token_store.dart';
import 'package:corp_portal_ui/features/corporate/corporate_models.dart';
import 'package:corp_portal_ui/features/pooling/pooling_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryTokenStore implements TokenStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

AuthState signedIn(String role) => AuthState(user: SessionUser(id: 'u1', name: 'Test User', email: 't@example.com', role: role, corporates: const [CorporateAccount(id: 'c1', name: 'Acme')]), corporateId: 'c1');

DataPool pool({String status = 'active', double? quota = 1000, double? used = 400}) => DataPool(
  id: 'p1', corporateId: 'c1', name: 'Main', corporate: 'Acme', status: status, quotaMb: quota, usedMb: used,
  createdAt: '2026-01-01T00:00:00Z', createdBy: 'a', updatedAt: '2026-01-01T00:00:00Z', updatedBy: 'a', sourceState: 'complete',
);

void main() {
  group('router guards', () {
    test('guests are sent to login, except guest pages', () {
      expect(portalRedirect(const AuthState(), Uri.parse('/dashboard')), '/login');
      expect(portalRedirect(const AuthState(), Uri.parse('/set-password?token=x')), isNull);
    });
    test('keeps the requested page while the session is restoring', () {
      expect(portalRedirect(const AuthState(booting: true), Uri.parse('/set-password?token=x')), isNull);
      expect(portalRedirect(const AuthState(booting: true), Uri.parse('/pooling')), isNull);
    });
    test('signed-in users skip guest pages', () {
      expect(portalRedirect(signedIn('corporate'), Uri.parse('/login')), '/dashboard');
    });
    test('users and roles pages are admin only', () {
      expect(portalRedirect(signedIn('sales'), Uri.parse('/users')), '/dashboard');
      expect(portalRedirect(signedIn('corporate'), Uri.parse('/roles')), '/dashboard');
      expect(portalRedirect(signedIn('admin'), Uri.parse('/users')), isNull);
      expect(portalRedirect(signedIn('sales'), Uri.parse('/pooling')), isNull);
    });
  });

  group('quota validation', () {
    test('rejects inactive or unknown pools', () {
      expect(quotaError(pool(status: 'inactive'), const QuotaDraft(direction: 'increase', amount: 1, reason: 'x')), PoolError.inactivePool);
      expect(quotaError(pool(quota: null), const QuotaDraft(direction: 'increase', amount: 1, reason: 'x')), PoolError.quotaUnknown);
    });
    test('decrease cannot exceed remaining data', () {
      expect(quotaError(pool(), const QuotaDraft(direction: 'decrease', amount: 601, reason: 'x')), PoolError.exceedsAvailable);
      expect(quotaError(pool(), const QuotaDraft(direction: 'decrease', amount: 600, reason: 'x')), isNull);
    });
    test('GB is converted like the CRM: 1 GB = 1,024 MB', () {
      expect(const QuotaDraft(direction: 'decrease', amount: 1.5, unit: DataUnit.gb).delta, -1536);
    });
    test('data sizes use 1,024-based units', () {
      expect(dataSize(30), '30 MB');
      expect(dataSize(1536), '1.5 GB');
      expect(dataSize(51200), '50 GB');
      expect(dataSize(2.5 * 1024 * 1024, terabytes: true), '2.5 TB');
    });
    test('reason is required', () {
      expect(quotaError(pool(), const QuotaDraft(direction: 'increase', amount: 1, reason: '  ')), PoolError.reasonRequired);
    });
  });

  test('unmapped statuses are counted as unknown, not as zero active', () {
    const allUnknown = NumberCounts(total: 53, active: 0, inactive: 0, suspended: 0);
    expect(allUnknown.unknown, 53);
    expect(allUnknown.statusUnknown, isTrue);
    const mixed = NumberCounts(total: 27, active: 19, inactive: 7, suspended: 0);
    expect(mixed.unknown, 1);
    expect(mixed.statusUnknown, isFalse);
    expect(const NumberCounts(total: 0, active: 0, inactive: 0, suspended: 0).statusUnknown, isFalse);
  });

  test('pool names are unique ignoring case', () {
    expect(poolError(const PoolDraft(name: 'MAIN'), [pool()], null), PoolError.duplicateName);
    expect(poolError(const PoolDraft(name: 'Main'), [pool()], 'p1'), isNull);
  });

  test('set password validates before calling the API', () {
    final repository = SessionRepository(PortalApi(const AppConfig(apiBaseUrl: 'http://api.test/api/v1')), MemoryTokenStore());
    expect(SetPasswordCubit(repository, '').validate('long enough password', 'long enough password'), SetPasswordProblem.missingLink);
    expect(SetPasswordCubit(repository, 't').validate('short', 'short'), SetPasswordProblem.tooShort);
    expect(SetPasswordCubit(repository, 't').validate('long enough password', 'different password'), SetPasswordProblem.mismatch);
  });

  testWidgets('opens the set-password page from an invite link', (tester) async {
    SharedPreferences.setMockInitialValues({'portal.locale': 'en'});
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/set-password?token=abc';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    final api = PortalApi(const AppConfig(apiBaseUrl: 'http://api.test/api/v1'), client: MockClient((_) async => http.Response('{}', 404)));
    await tester.pumpWidget(PortalApp(api: api, tokenStore: MemoryTokenStore()));
    await tester.pumpAndSettle();
    expect(find.text('Set your password'), findsOneWidget);
  });

  testWidgets('uses the saved dark theme', (tester) async {
    SharedPreferences.setMockInitialValues({'portal.locale': 'en', 'portal.theme': 'dark'});
    final api = PortalApi(const AppConfig(apiBaseUrl: 'http://api.test/api/v1'), client: MockClient((_) async => http.Response('{}', 404)));
    await tester.pumpWidget(PortalApp(api: api, tokenStore: MemoryTokenStore()));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Welcome to Corp Portal'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).extension<PortalPalette>(), PortalPalette.dark);
  });

  testWidgets('shows the login page without a saved session', (tester) async {
    SharedPreferences.setMockInitialValues({'portal.locale': 'en'});
    final api = PortalApi(const AppConfig(apiBaseUrl: 'http://api.test/api/v1'), client: MockClient((_) async => http.Response(jsonEncode({}), 404)));
    await tester.pumpWidget(PortalApp(api: api, tokenStore: MemoryTokenStore()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Corp Portal'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
