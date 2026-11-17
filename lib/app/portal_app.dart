import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:go_router/go_router.dart';
import '../core/api/portal_api.dart';
import '../core/config/app_config.dart';
import '../core/i18n/locale_cubit.dart';
import '../core/theme/theme_mode_cubit.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/data/session_repository.dart';
import '../features/auth/data/token_store.dart';
import '../features/auth/pages/session_recovery.dart';

import 'responsive_typography.dart';
import 'router.dart';
import 'theme.dart';

/// Composition root: one API client, session and auth bloc for the whole app.
class PortalApp extends StatefulWidget {
  const PortalApp({super.key, this.config = const AppConfig(), this.api, this.tokenStore});
  final AppConfig config;
  final PortalApi? api;
  final TokenStore? tokenStore;
  @override
  State<PortalApp> createState() => _PortalAppState();
}

class _PortalAppState extends State<PortalApp> {
  late final PortalApi _api = widget.api ?? PortalApi(widget.config);
  late final SessionRepository _session = SessionRepository(_api, widget.tokenStore ?? createTokenStore());
  late final AuthBloc _auth = AuthBloc(_session)..add(AuthStarted());
  late final LocaleCubit _locale = LocaleCubit()..restore();
  late final ThemeModeCubit _themeMode = ThemeModeCubit()..restore();
  late final GoRouter _router = createRouter(_auth);

  @override
  void dispose() {
    _router.dispose();
    _auth.close();
    _locale.close();
    _themeMode.close();
    _session.close();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  static final _light = portalTheme();
  static final _dark = portalTheme(Brightness.dark);


  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: widget.config),
      RepositoryProvider.value(value: _api),
      RepositoryProvider.value(value: _session),
    ],
    child: MultiBlocProvider(
      providers: [BlocProvider.value(value: _auth), BlocProvider.value(value: _locale), BlocProvider.value(value: _themeMode)],
      child: BlocBuilder<ThemeModeCubit, ThemeMode>(builder: (context, mode) => BlocBuilder<LocaleCubit, Locale>(builder: (context, locale) => MaterialApp.router(
        title: 'Corp Portal',
        theme: _light, darkTheme: _dark, themeMode: mode,
        locale: locale,
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('th'), Locale('en')],
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        // The router exists from the first frame so it keeps the browser's starting URL
        // (e.g. a set-password link). Its guards wait for session restore; until then a
        // spinner covers the pages.
        builder: (context, child) => ResponsiveTypography(child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) {
            if (auth.booting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            if (auth.recoveryRequired && !auth.authenticated) return SessionRecovery(auth: auth);
            if (!auth.recoveryRequired) return child!;
            return Column(children: [
              Material(color: Theme.of(context).colorScheme.surfaceContainer, child: Padding(
                padding: const EdgeInsets.all(12), child: Wrap(spacing: 16, runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(context.tr('Connection interrupted. Your session has been kept.', 'การเชื่อมต่อขัดข้อง เก็บเซสชันเดิมไว้แล้ว')),
                    RecoveryActions(auth: auth),
                  ],
                ),
              )),
              Expanded(child: child!),
            ]);
          },
        )),
      ))),
    ),
  );
}

