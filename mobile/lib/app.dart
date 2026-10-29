import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api/api_client.dart';
import 'api/api_exception.dart';
import 'app_scope.dart';
import 'config.dart';
import 'models/app_user.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';
import 'session/session_store.dart';
import 'theme/ambient_backdrop.dart';
import 'theme/app_theme.dart';
import 'widgets/state_views.dart';

class MeetingActionApp extends StatefulWidget {
  const MeetingActionApp({super.key, required this.config, required this.sessionStore, this.httpClient});

  final AppConfig config;
  final SessionStore sessionStore;
  final http.Client? httpClient;

  @override
  State<MeetingActionApp> createState() => _MeetingActionAppState();
}

class _MeetingActionAppState extends State<MeetingActionApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final ApiClient _api = ApiClient(
    baseUrl: widget.config.apiBaseUrl,
    httpClient: widget.httpClient,
    onUnauthorized: _handleUnauthorized,
  );

  AppUser? _user;
  bool _restoring = true;
  ApiException? _restoreError;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Reuses the stored dev token after an app restart, after checking it with the server.
  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _restoreError = null;
    });
    final stored = await widget.sessionStore.load();
    if (stored == null) {
      if (mounted) setState(() => _restoring = false);
      return;
    }
    _api.token = stored.token;
    try {
      final user = await _api.me();
      await widget.sessionStore.save(Session(token: stored.token, user: user));
      if (mounted) setState(() => _user = user);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await widget.sessionStore.clear();
        _api.token = null;
      } else if (mounted) {
        setState(() => _restoreError = e);
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _signedIn(Session session) async {
    _api.token = session.token;
    await widget.sessionStore.save(session);
    if (mounted) setState(() => _user = session.user);
  }

  Future<void> _signOut() async {
    await widget.sessionStore.clear();
    _api.token = null;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (mounted) {
      setState(() {
        _user = null;
        _restoreError = null;
      });
    }
  }

  void _handleUnauthorized() {
    if (_user == null) return;
    _signOut();
    _messengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Your session expired. Sign in again.')));
  }

  Widget _home() {
    if (_restoring) return const Scaffold(body: AmbientBackdrop(child: LoadingView()));
    if (_restoreError != null) {
      return Scaffold(
        body: AmbientBackdrop(
          child: Center(
            child: EmptyView(
              icon: Icons.cloud_off_outlined,
              title: 'Cannot reach the server',
              message: _restoreError!.message,
              action: Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(onPressed: _restore, child: const Text('Try again')),
                  TextButton(onPressed: _signOut, child: const Text('Sign out')),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_user == null) return SignInScreen(api: _api, onSignedIn: _signedIn);
    return const HomeShell();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: _api,
      user: _user,
      onSignOut: _signOut,
      child: MaterialApp(
        title: 'Meeting → Action',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        // One clock for every screen's backdrop, so pages slide over one scene.
        builder: (context, child) => AmbientClock(child: child!),
        home: _home(),
      ),
    );
  }
}
