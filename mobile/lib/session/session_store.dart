import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Keeps the development sign-in across app restarts. A production app would
/// keep a real credential in the Keychain/Keystore instead.
abstract class SessionStore {
  Future<Session?> load();
  Future<void> save(Session session);
  Future<void> clear();
}

class SharedPreferencesSessionStore implements SessionStore {
  static const _tokenKey = 'session.token';
  static const _userKey = 'session.user';

  @override
  Future<Session?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final user = prefs.getString(_userKey);
    if (token == null || user == null) return null;
    try {
      return Session(token: token, user: AppUser.fromJson(jsonDecode(user) as Map<String, dynamic>));
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_userKey, jsonEncode(session.user.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}

class InMemorySessionStore implements SessionStore {
  Session? _session;

  @override
  Future<Session?> load() async => _session;

  @override
  Future<void> save(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
